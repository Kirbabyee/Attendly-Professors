import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AttendanceRecord {
  final String courseName;
  final String className; // for dropdown "Filter by class"
  final DateTime date;

  AttendanceRecord({
    required this.courseName,
    required this.className,
    required this.date,
  });
}

class DataFilter extends StatefulWidget {
  const DataFilter({super.key});

  @override
  State<DataFilter> createState() => _DataFilterState();
}

class _DataFilterState extends State<DataFilter> {
  List<String> classOptions = ['All'];

  final TextEditingController searchController = TextEditingController();

  String selectedStatus = 'All'; // chips: All/Present/Late/Absent
  String selectedClass = 'All';  // dropdown: Filter by class

  DateTime? selectedDate;

  List<AttendanceRecord> allRecords = [];
  List<AttendanceRecord> filteredRecords = [];

  @override
  void initState() {
    super.initState();

    allRecords = [
      AttendanceRecord(
        courseName: 'Introduction to Computer Interaction',
        className: 'CCS101',
        date: DateTime(2025, 12, 12),
      ),
      AttendanceRecord(
        courseName: 'Introduction to Computer Interaction',
        className: 'CCS101',
        date: DateTime(2025, 12, 11),
      ),
      AttendanceRecord(
        courseName: 'Software Engineering',
        className: 'CCS125',
        date: DateTime(2025, 12, 14),
      ),
      AttendanceRecord(
        courseName: 'Software Engineering',
        className: 'CCS125',
        date: DateTime(2025, 11, 25),
      ),
      AttendanceRecord(
        courseName: 'Software Engineering',
        className: 'CCS125',
        date: DateTime(2025, 12, 14),
      ),
    ];

    filteredRecords = List.from(allRecords); // show all at start

    classOptions = [
      'All',
      ...{ for (final r in allRecords) r.courseName }
    ];
  }

  void applyFilters() {
    final query = searchController.text.trim().toLowerCase();

    setState(() {
      filteredRecords = allRecords.where((record) {
        // Search filter
        final matchesSearch =
        record.courseName.toLowerCase().contains(query);

        // Dropdown filter
        final matchesClass =
            selectedClass == 'All' || record.courseName == selectedClass;

        // Date filter (same day only)
        final matchesDate = selectedDate == null ||
            (record.date.year == selectedDate!.year &&
                record.date.month == selectedDate!.month &&
                record.date.day == selectedDate!.day);

        return matchesSearch && matchesClass && matchesDate;
      }).toList();
    });
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,     // header & selected date
              onPrimary: Colors.white,  // header text
              surface: Colors.white,    // ✅ dialog background
              onSurface: Colors.black,  // body text
            ),
            dialogBackgroundColor: Colors.white, // ✅ ensures white bg
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      applyFilters();
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: screenHeight > 700 ? 350 : 320,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Search
                Center(
                  child: SizedBox(
                    height: screenHeight > 700 ? 40 : 35,
                    child: TextField(
                      style: TextStyle(
                        fontSize: screenHeight > 700 ? 16 : 14
                      ),
                      controller: searchController,
                      onChanged: (_) => applyFilters(),
                      decoration: InputDecoration(
                        hintStyle: TextStyle(
                          fontSize: screenHeight > 700 ? 16 : 14
                        ),
                        hintText: 'Search course',
                        prefixIcon: const Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 10,),

                Container(
                  child: Row(
                    children: [
                      // Date Filter Row
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.35,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: const Color(0xFFEAEAEA),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: pickDate,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedDate == null
                                      ? 'Select date'
                                      : _fmt(selectedDate!),
                                  style: const TextStyle(fontSize: 12, color: Colors.black),
                                ),
                                if (selectedDate != null)
                                  GestureDetector(
                                    onTap: () {
                                      setState(() => selectedDate = null);
                                      applyFilters();
                                    },
                                    child: const Icon(Icons.close, size: 16),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(width: screenHeight * .09),

                      // Dropdown
                      Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.3,
                          child: DropdownButton<String>(
                            isExpanded: true, // important so it uses the SizedBox width
                            dropdownColor: Colors.white,
                            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            value: selectedClass,
                            items: classOptions.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(
                                  c,
                                  overflow: TextOverflow.ellipsis, // prevent long text overflow
                                  maxLines: 1,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => selectedClass = value);
                              applyFilters();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10,),

                // Title + Chips
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: screenHeight > 700 ? 15 : 14),
                    ),
                    screenHeight > 700 ? SizedBox(height: 5) : SizedBox(),
                  ],
                ),

                SizedBox(height: screenHeight > 700 ? 10 : 5),

                // ✅ LIST AREA (scrollable)
                Expanded(
                  child: filteredRecords.isEmpty
                      ? const Center(child: Text('No records found.'))
                      : ListView.builder(
                    itemCount: filteredRecords.length,
                    itemBuilder: (context, index) {
                      final record = filteredRecords[index];
                      final bg = index.isEven
                          ? Colors.white
                          : Colors.grey[300];

                      return Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: bg,
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: ListTile(
                            title: Text(
                              record.courseName,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: screenHeight > 700 ? 12 : 11
                              ),
                            ),
                            subtitle: Text(
                              '${record.className} • ${record.date.toIso8601String().split("T")[0]}',
                              style: TextStyle(
                                fontSize: screenHeight > 700 ? 11 : 10
                              ),
                            ),
                            trailing: SizedBox(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  backgroundColor: Color(0xFF004280),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadiusGeometry.circular(6)
                                  ),
                                  side: BorderSide.none
                                ),
                                onPressed: () {},
                                icon: Icon(
                                  Icons.download,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  'Export CSV',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.white
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

