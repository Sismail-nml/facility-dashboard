import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortColumn = 'recorded_at';
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    var result = data;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) {
        final rig = (r['rig_name'] as String? ?? '').toLowerCase();
        final op = (r['operator_name'] as String? ?? '').toLowerCase();
        final meta = r['metadata']?.toString().toLowerCase() ?? '';
        return rig.contains(q) || op.contains(q) || meta.contains(q);
      }).toList();
    }

    result.sort((a, b) {
      final va = a[_sortColumn]?.toString() ?? '';
      final vb = b[_sortColumn]?.toString() ?? '';
      return _sortAscending ? va.compareTo(vb) : vb.compareTo(va);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.mic, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Test Facility Recordings',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by rig, operator, or metadata…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFFF0F0EE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.watchRecordings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final recordings = _applyFilters(snapshot.data ?? []);

          if (recordings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_none, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'No results for "$_searchQuery"'
                        : 'No recordings yet',
                    style: const TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  '${recordings.length} recording${recordings.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              Expanded(
                child: _RecordingsTable(
                  recordings: recordings,
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: (col, asc) => setState(() {
                    _sortColumn = col;
                    _sortAscending = asc;
                  }),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Table ─────────────────────────────────────────────────────────────────────

class _RecordingsTable extends StatelessWidget {
  final List<Map<String, dynamic>> recordings;
  final String sortColumn;
  final bool sortAscending;
  final void Function(String col, bool asc) onSort;

  const _RecordingsTable({
    required this.recordings,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  static const _presetKeys = {
    'Side', 'Component', 'Angle', 'Location on System',
    'Mic Position', 'Mic Distance (mm)', 'Mic Direction', 'Observations',
  };

  int? _sortIndex(String col) {
    const cols = ['rig_name', 'operator_name', 'recorded_at'];
    final i = cols.indexOf(col);
    return i == -1 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SingleChildScrollView(
              child: DataTable(
                sortColumnIndex: _sortIndex(sortColumn),
                sortAscending: sortAscending,
                headingRowColor: WidgetStateProperty.all(Colors.white),
                headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 13),
                dataRowColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered)) {
                    return const Color(0xFFF0F0EE);
                  }
                  return Colors.white;
                }),
                border: TableBorder(
                  horizontalInside: BorderSide(color: Colors.grey.shade100),
                  bottom: BorderSide(color: Colors.grey.shade100),
                ),
                columnSpacing: 24,
                columns: [
                  _sortableCol('Rig Name', 'rig_name'),
                  _sortableCol('Operator', 'operator_name'),
                  _sortableCol('Date & Time', 'recorded_at'),
                  const DataColumn(label: Text('Media')),
                  const DataColumn(label: Text('Side')),
                  const DataColumn(label: Text('Component')),
                  const DataColumn(label: Text('Observations')),
                  const DataColumn(label: Text('Extra Fields')),
                ],
                rows: recordings.map((r) => _buildRow(context, r)).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  DataColumn _sortableCol(String label, String field) {
    return DataColumn(
      label: Text(label),
      onSort: (_, asc) => onSort(field, asc),
    );
  }

  DataRow _buildRow(BuildContext context, Map<String, dynamic> rec) {
    final date = DateTime.parse(rec['recorded_at'] as String);
    final metadata =
        Map<String, dynamic>.from(rec['metadata'] as Map? ?? {});
    final mediaType = rec['media_type']?.toString() ?? 'audio';
    final hasMedia = rec['audio_url'] != null;

    final side = metadata['Side']?.toString() ?? '—';
    final component = metadata['Component']?.toString() ?? '—';
    final observations = metadata['Observations']?.toString() ?? '—';
    final extraCount =
        metadata.keys.where((k) => !_presetKeys.contains(k)).length;

    final mediaIcon = switch (mediaType) {
      'photo' => Icons.photo_camera,
      'video' => Icons.videocam,
      _ => Icons.mic,
    };

    return DataRow(
      onSelectChanged: (_) => _showDetail(context, rec),
      cells: [
        DataCell(Text(
          rec['rig_name'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600),
        )),
        DataCell(Text(rec['operator_name'] as String? ?? '—')),
        DataCell(Text(DateFormat('dd MMM yyyy, HH:mm').format(date))),
        DataCell(Icon(
          mediaIcon,
          color: hasMedia ? Colors.green : Colors.grey.shade400,
          size: 18,
        )),
        DataCell(Text(side)),
        DataCell(Text(component)),
        DataCell(Text(
          observations.length > 40
              ? '${observations.substring(0, 40)}…'
              : observations,
        )),
        DataCell(extraCount > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '+$extraCount',
                  style: TextStyle(
                      color: Colors.blue.shade700, fontSize: 12),
                ),
              )
            : const Text('—')),
      ],
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> rec) {
    showDialog(
      context: context,
      builder: (_) => _DetailDialog(recording: rec),
    );
  }
}

// ── Detail dialog ─────────────────────────────────────────────────────────────

class _DetailDialog extends StatefulWidget {
  final Map<String, dynamic> recording;
  const _DetailDialog({required this.recording});

  @override
  State<_DetailDialog> createState() => _DetailDialogState();
}

class _DetailDialogState extends State<_DetailDialog> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rec = widget.recording;
    final date = DateTime.parse(rec['recorded_at'] as String);
    final metadata =
        Map<String, dynamic>.from(rec['metadata'] as Map? ?? {});
    final audioUrl = rec['audio_url'] as String?;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec['rig_name'] as String? ?? '',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              DateFormat('EEEE, d MMMM yyyy — HH:mm').format(date),
              style: const TextStyle(color: Colors.grey),
            ),
            if ((rec['operator_name'] as String?)?.isNotEmpty == true)
              Text(
                'Operator: ${rec['operator_name']}',
                style: const TextStyle(color: Colors.grey),
              ),

            const Divider(height: 28),

            // Audio player
            if (audioUrl != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ListTile(
                  leading: Icon(Icons.audiotrack,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Audio Recording'),
                  subtitle: Text(_isPlaying ? 'Playing…' : 'Tap to play'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () async {
                          if (_isPlaying) {
                            await _player.stop();
                          } else {
                            await _player.play(UrlSource(audioUrl));
                          }
                          setState(() => _isPlaying = !_isPlaying);
                        },
                        icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Play',
                      ),
                      IconButton(
                        onPressed: () async {
                          final uri = Uri.parse('$audioUrl?download=recording.m4a');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(Icons.download),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Download',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Metadata
            if (metadata.isNotEmpty) ...[
              const Text('Metadata',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              ...metadata.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 180,
                        child: Text(e.key,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      Expanded(
                        child: Text(
                          e.value.toString(),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              const Text('No metadata recorded.',
                  style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
