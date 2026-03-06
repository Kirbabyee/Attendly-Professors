// supabase/functions/auto-end-sessions/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TZ = "Asia/Manila";

/**
 * Returns a Date object representing "now" in the given time zone
 * by parsing locale string back into Date (common, simple approach for Edge).
 */
function nowInTZ(tz: string) {
  return new Date(new Date().toLocaleString("en-US", { timeZone: tz }));
}

/**
 * Convert a Date (assumed already representing local time components)
 * into a UTC ISO string by using its epoch (Date always stores epoch).
 */
function toISO(d: Date) {
  return new Date(d.getTime()).toISOString();
}

/**
 * Build Manila day start/end (00:00:00 to 23:59:59.999) and return as Date objects
 */
function manilaDayWindow(nowManila: Date) {
  const start = new Date(nowManila);
  start.setHours(0, 0, 0, 0);

  const end = new Date(nowManila);
  end.setHours(23, 59, 59, 999);

  return { start, end };
}

/**
 * Parse schedule like:
 * "Mon 10:00-12:00"
 * "Mon 10:00 - 12:00"
 * Also supports 1-2 digit hours
 */
function parseSchedule(schedule: string) {
  // Accepts:
  // "Wednesday: 05:17 PM - 06:00 PM"
  // Also tolerates extra spaces.

  const re = /^(Sunday|Monday|Tuesday|Wednesday|Thursday|Friday|Saturday):\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*-\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$/i;

  const match = schedule.match(re);
  if (!match) return null;

  const dayName = match[1];
  const sh = match[2], sm = match[3], sampm = match[4];
  const eh = match[5], em = match[6], eampm = match[7];

  const dayMap: Record<string, number> = {
    sunday: 0,
    monday: 1,
    tuesday: 2,
    wednesday: 3,
    thursday: 4,
    friday: 5,
    saturday: 6,
  };

  function to24(h: number, ampm: string) {
    const A = ampm.toUpperCase();
    if (A === "PM" && h !== 12) return h + 12;
    if (A === "AM" && h === 12) return 0;
    return h;
  }

  const startH = to24(parseInt(sh, 10), sampm);
  const endH = to24(parseInt(eh, 10), eampm);

  return {
    schedDay: dayMap[dayName.toLowerCase()],
    startH,
    startM: parseInt(sm, 10),
    endH,
    endM: parseInt(em, 10),
  };
}

/**
 * Builds the schedule occurrence window (start/end) for "today",
 * including overnight schedules (e.g., 22:00-01:00).
 *
 * Rules:
 * - If schedule is not today, returns null.
 * - For overnight (end <= start):
 *    - If today is schedule day: window is today start -> tomorrow end
 *    - If today is next day: window is yesterday start -> today end (spill)
 */
function getOccurrenceWindow(schedule: string, nowManila: Date) {
  const parsed = parseSchedule(schedule);
  if (!parsed) return null;

  const nowDow = nowManila.getDay();
  const { schedDay, startH, startM, endH, endM } = parsed;

  // helper to clone date
  const clone = (d: Date) => new Date(d.getTime());

  // build today's start/end times
  const todayStart = clone(nowManila);
  todayStart.setHours(startH, startM, 0, 0);

  const todayEnd = clone(nowManila);
  todayEnd.setHours(endH, endM, 0, 0);

  const isOvernight =
    endH < startH || (endH === startH && endM <= startM);

  // Normal (not overnight)
  if (!isOvernight) {
    if (nowDow !== schedDay) return null;
    return { start: todayStart, end: todayEnd, isOvernight: false, mode: "normal" };
  }

  // Overnight schedule
  // Case A: today is the scheduled day (start today, end tomorrow)
  if (nowDow === schedDay) {
    const endTomorrow = clone(todayEnd);
    endTomorrow.setDate(endTomorrow.getDate() + 1);
    return { start: todayStart, end: endTomorrow, isOvernight: true, mode: "overnight_today" };
  }

  // Case B: today is the next day (spill from yesterday)
  // Example: schedDay = Mon (1), overnight 22:00-01:00
  // On Tue (2) at 00:30, it's still part of Monday's session.
  const nextDayOfSched = (schedDay + 1) % 7;
  if (nowDow === nextDayOfSched) {
    const startYesterday = clone(todayStart);
    startYesterday.setDate(startYesterday.getDate() - 1);

    const endToday = clone(todayEnd); // end is today at endH:endM
    return { start: startYesterday, end: endToday, isOvernight: true, mode: "overnight_spill" };
  }

  return null;
}

/**
 * Determine session status relative to occurrence window
 */
function getSessionStatus(schedule: string, nowManila: Date): "Not Today" | "Ongoing" | "Ended" | "Unknown" {
  const occ = getOccurrenceWindow(schedule, nowManila);
  if (!occ) {
    // schedule not applicable today/spill
    const parsed = parseSchedule(schedule);
    return parsed ? "Not Today" : "Unknown";
  }

  if (nowManila > occ.end) return "Ended";
  if (nowManila >= occ.start && nowManila <= occ.end) return "Ongoing";
  // before start
  return "Not Today";
}

/**
 * Return the schedule end Date for the current occurrence (today/spill)
 */
function getScheduleEndTime(schedule: string, nowManila: Date): Date | null {
  const occ = getOccurrenceWindow(schedule, nowManila);
  return occ ? occ.end : null;
}

serve(async (_req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    // ✅ Use Manila time for schedule logic
    const nowManila = nowInTZ(TZ);

    // ✅ Use UTC ISO for DB timestamps
    const nowISO = new Date().toISOString();

    // 1️⃣ Get all active classes with schedules
    const { data: classes, error: classError } = await supabaseClient
      .from("classes")
      .select("id, schedule, professor_id")
      .eq("archived", false);

    if (classError) throw classError;

    if (!classes || classes.length === 0) {
      return new Response(JSON.stringify({ message: "No active classes" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    const classIds = classes.map((c) => c.id);

    // 2️⃣ Get all started sessions
    const { data: startedSessions, error: startedErr } = await supabaseClient
      .from("class_sessions")
      .select("id, class_id")
      .in("class_id", classIds)
      .eq("status", "started");

    if (startedErr) throw startedErr;

    const startedByClass = new Map(
      (startedSessions ?? []).map((s) => [s.class_id, s.id])
    );

    let endedCount = 0;

    // Manila day window for "system ended already today" check
    const { start: manilaStart, end: manilaEnd } = manilaDayWindow(nowManila);
    const startOfDayUTCISO = toISO(manilaStart);
    const endOfDayUTCISO = toISO(manilaEnd);

    // 3️⃣ Process each class
    for (const cls of classes) {
      const classId = cls.id as string;
      const schedule = cls.schedule as string | null;

      if (!schedule) {
        console.log("[skip] no schedule", { classId });
        continue;
      }

      const statusBySched = getSessionStatus(schedule, nowManila);
      const sessionId = startedByClass.get(classId);

      console.log("[class]", {
        classId,
        schedule,
        statusBySched,
        sessionId: sessionId ?? null,
        nowManila: nowManila.toISOString(),
      });

      // A) No session started, but schedule ended → insert "system ended" once per Manila day
      // A) No session started, but schedule ended → insert "system ended"
      // ✅ BUT only if there was NO session at all today for that class
      if (!sessionId && statusBySched === "Ended") {

        // ✅ Block only if there is already an ended/system-ended marker today
        const endedStatuses = [
          "ended",
          "system ended",
          "system ended (session was not started)",
        ];

        const { data: endedToday, error: endedTodayErr } = await supabaseClient
          .from("class_sessions")
          .select("id, status")
          .eq("class_id", classId)
          .in("status", endedStatuses)
          .gte("ended_at", startOfDayUTCISO)
          .lte("ended_at", endOfDayUTCISO)
          .limit(1);

        if (endedTodayErr) throw endedTodayErr;

        if (endedToday && endedToday.length > 0) {
          console.log("[skip insert] already has ended/system-ended today", { classId });
          continue;
        }

        // ✅ Otherwise insert the not-started marker
        const { data: inserted, error: insErr } = await supabaseClient
          .from("class_sessions")
          .insert({
            class_id: classId,
            status: "system ended (session was not started)",
            ended_at: nowISO, // UTC
          })
          .select("id")
          .single();

        if (insErr) throw insErr;

        const newSessionId = inserted.id as string;

        console.log("[insert system ended not-started]", {
          classId,
          sessionId: newSessionId,
          ended_at: nowISO,
        });

        endedCount++;
        continue;
      }

      // B) Session started → check if past schedule end + 2 mins
      if (sessionId) {
        const schedEnd = getScheduleEndTime(schedule, nowManila);
        if (!schedEnd) {
          console.log("[skip] cannot parse schedEnd", { classId, schedule });
          continue;
        }

        const endAt = new Date(schedEnd.getTime() + 2 * 60 * 1000); // +2 mins grace

        console.log("[check end]", {
          classId,
          schedEnd: schedEnd.toISOString(),
          endAt: endAt.toISOString(),
          nowManila: nowManila.toISOString(),
          nowGTendAt: nowManila > endAt,
        });

        if (nowManila > endAt) {
          const { data: updated, error: updErr } = await supabaseClient
            .from("class_sessions")
            .update({ status: "system ended", ended_at: nowISO })
            .eq("id", sessionId)
            .eq("status", "started")
            .select("id");

          if (updErr) throw updErr;

          if (updated && updated.length > 0) {
            console.log("[updated session -> system ended]", {
              classId,
              sessionId,
              ended_at: nowISO,
            });

            await finalizeAttendance(supabaseClient, classId, sessionId, nowISO, cls.professor_id ?? null);
            endedCount++;
          } else {
            console.log("[no update] session not started anymore?", { classId, sessionId });
          }
        }
      }
    }

    return new Response(JSON.stringify({ success: true, endedCount }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.log("[ERROR]", error);
    return new Response(JSON.stringify({ error: error?.message ?? String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

async function finalizeAttendance(
  supabase: any,
  classId: string,
  sessionId: string,
  endedAtIsoUTC: string,
  professorId: string | null
) {
  // 0) Guard: don’t double-insert history if already finalized
  const { data: histExists, error: histExistsErr } = await supabase
    .from("attendance_history")
    .select("id")
    .eq("session_id", sessionId)
    .eq("reason", "Session ended - finalized attendance")
    .limit(1);

  if (histExistsErr) throw histExistsErr;

  if (histExists && histExists.length > 0) {
    // still ensure time_out is set (safe)
    const { error: safeErr } = await supabase
      .from("attendance")
      .update({ time_out: endedAtIsoUTC })
      .eq("session_id", sessionId)
      .in("status", ["present", "late"])
      .is("time_out", null);

    if (safeErr) throw safeErr;
    return;
  }

  // 1) Get enrolled students
  const { data: enrolled, error: enrollErr } = await supabase
    .from("class_enrollments")
    .select("student_id")
    .eq("class_id", classId);

  if (enrollErr) throw enrollErr;
  if (!enrolled || enrolled.length === 0) return;

  const enrolledIds = enrolled.map((e: any) => e.student_id);

  // 2) Get existing attendance rows (with id + status)
  const { data: existing, error: existErr } = await supabase
    .from("attendance")
    .select("id, student_id, status")
    .eq("session_id", sessionId);

  if (existErr) throw existErr;

  const existingIds = new Set((existing ?? []).map((a: any) => a.student_id));

  // 3) Insert missing students as ABSENT
  const missing = enrolledIds.filter((sid: string) => !existingIds.has(sid));

  if (missing.length > 0) {
    const payload = missing.map((sid: string) => ({
      session_id: sessionId,
      student_id: sid,
      status: "absent",
      time_in: null,
      time_out: null,
    }));

    const { error: upsertErr } = await supabase
      .from("attendance")
      .upsert(payload, { onConflict: "session_id,student_id" });

    if (upsertErr) throw upsertErr;
  }

  // 4) Set time_out for present/late
  const { error: outErr } = await supabase
    .from("attendance")
    .update({ time_out: endedAtIsoUTC })
    .eq("session_id", sessionId)
    .in("status", ["present", "late"])
    .is("time_out", null);

  if (outErr) throw outErr;

  // 5) Re-fetch ALL attendance rows now (with IDs)
  const { data: allRows, error: allErr } = await supabase
    .from("attendance")
    .select("id, student_id, status")
    .eq("session_id", sessionId);

  if (allErr) throw allErr;
  if (!allRows || allRows.length === 0) return;

  // 6) Insert history for ALL rows (must match DB constraint)
  const actionFromStatus = (st: string) => {
    if (st === "absent") return "auto_absent";
    if (st === "late") return "mark_late";
    if (st === "excused") return "update_status"; // ✅ FIX: mark_excused not allowed
    return "mark_present";
  };

if (!professorId) throw new Error("professorId is required for attendance_history.changed_by");

  const historyPayload = allRows.map((r: any) => {
    const st = (r.status as string) ?? "present";
    return {
      attendance_id: r.id,
      session_id: sessionId,
      student_id: r.student_id,

      professor_id: professorId ?? null,  // ✅ FK-safe
      old_status: null,
      new_status: st,
      action: actionFromStatus(st),
      changed_by: professorId ?? professorId,
      changed_by_role: "system",
      reason: "Session ended - finalized attendance",
      changed_at: endedAtIsoUTC,
    };
  });

  const { data: histData, error: histErr } = await supabase
    .from("attendance_history")
    .insert(historyPayload)
    .select("id");

  if (histErr) {
    console.log("[attendance_history FAILED - finalizeAttendance]", {
      message: histErr.message,
      details: histErr.details,
      hint: histErr.hint,
      code: histErr.code,
      sample: historyPayload?.[0],
    });
    throw histErr;
  }

  console.log("[attendance_history OK - finalizeAttendance]", {
    inserted: histData?.length ?? 0,
    sessionId,
  });
}