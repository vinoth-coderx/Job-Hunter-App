import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/applicant_model.dart';
import '../data/services/applicants_service.dart';
import '../data/services/chat_service.dart';

class ApplicantsProvider extends ChangeNotifier {
  final ApplicantsService _service = ApplicantsService.instance;
  StreamSubscription? _newApplicantSub;

  ApplicantsProvider() {
    // Live new-applicant push: when the seeker applies, the hirer's
    // current scope (specific job or "all") refetches so the row appears
    // without a manual pull-to-refresh.
    _newApplicantSub =
        ChatService.instance.onApplicantNew.listen(_onNewApplicant);
  }

  // Holds whichever scope was last loaded (job-scoped or global).
  final List<Applicant> _items = [];
  String? _scopedJobId;
  String? _scopedJobTitle;
  String _statusFilter = 'all';
  bool _loading = false;
  String? _error;
  int _total = 0;

  void _onNewApplicant(
      ({String applicationId, String jobId, double? matchScore}) e) {
    // If a job is scoped and the new applicant doesn't belong to it,
    // ignore — they'll show up next time the hirer opens that job. For
    // unscoped (global) view, always refresh.
    if (_scopedJobId != null && _scopedJobId != e.jobId) return;
    if (_scopedJobId != null) {
      loadForJob(jobId: _scopedJobId!);
    } else {
      loadAll();
    }
  }

  @override
  void dispose() {
    _newApplicantSub?.cancel();
    super.dispose();
  }

  List<Applicant> get items => List.unmodifiable(_items);
  String? get scopedJobId => _scopedJobId;
  String? get scopedJobTitle => _scopedJobTitle;
  String get statusFilter => _statusFilter;
  bool get loading => _loading;
  String? get error => _error;
  int get total => _total;

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }

  Future<void> loadForJob({
    required String jobId,
    String? status,
  }) async {
    _scopedJobId = jobId;
    if (status != null) _statusFilter = status;
    _setLoading(true);
    _error = null;
    try {
      final res = await _service.listForJob(
        jobId: jobId,
        status: _statusFilter,
      );
      _items
        ..clear()
        ..addAll(res.items);
      _total = res.total;
      _scopedJobTitle = res.jobTitle;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAll({String? status}) async {
    _scopedJobId = null;
    _scopedJobTitle = null;
    if (status != null) _statusFilter = status;
    _setLoading(true);
    _error = null;
    try {
      final res = await _service.listAll(status: _statusFilter);
      _items
        ..clear()
        ..addAll(res.items);
      _total = res.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateStatus({
    required String applicationId,
    required String status,
    String? note,
    String? rejectionReason,
  }) async {
    _error = null;
    try {
      final newStatus = await _service.updateStatus(
        id: applicationId,
        status: status,
        note: note,
        rejectionReason: rejectionReason,
      );
      // Optimistic local update.
      final idx = _items.indexWhere((a) => a.applicationId == applicationId);
      if (idx >= 0) {
        final old = _items[idx];
        _items[idx] = Applicant(
          applicationId: old.applicationId,
          jobId: old.jobId,
          status: newStatus,
          matchScore: old.matchScore,
          appliedAt: old.appliedAt,
          applyType: old.applyType,
          source: old.source,
          quickNote: old.quickNote,
          resumeUrlSnapshot: old.resumeUrlSnapshot,
          screeningAnswers: old.screeningAnswers,
          hirerNotes: old.hirerNotes,
          rejectionReason: rejectionReason ?? old.rejectionReason,
          statusHistory: old.statusHistory,
          seeker: old.seeker,
          jobSnapshot: old.jobSnapshot,
        );
      }
      // If filter is non-'all' and the new status no longer matches, drop it.
      if (_statusFilter != 'all' && _statusFilter != newStatus) {
        _items.removeWhere((a) => a.applicationId == applicationId);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<Applicant?> getDetail(String id) async {
    _error = null;
    try {
      return await _service.getDetail(id);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> bulkUpdate({
    required List<String> ids,
    required String status,
  }) async {
    _error = null;
    try {
      await _service.bulkUpdate(ids: ids, status: status);
      // Easiest way to reflect server state is to reload current scope.
      if (_scopedJobId != null) {
        await loadForJob(jobId: _scopedJobId!);
      } else {
        await loadAll();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
