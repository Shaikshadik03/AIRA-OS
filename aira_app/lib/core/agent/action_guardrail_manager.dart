import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aira_app/core/agent/self_check_reflector.dart';

enum ApprovalStatus {
  pending,
  approved,
  rejected,
  edited,
}

/// Pending Action awaiting human-in-the-loop confirmation
class PendingApprovalAction {
  final String id;
  final String actionType; // 'email', 'sms', 'call', 'workspace_write', 'workspace_delete'
  final String recipient;
  final String subject;
  final String content;
  final SelfCheckAuditRecord? auditRecord;
  ApprovalStatus status;
  final DateTime createdAt;

  PendingApprovalAction({
    required this.id,
    required this.actionType,
    required this.recipient,
    required this.subject,
    required this.content,
    this.auditRecord,
    this.status = ApprovalStatus.pending,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'actionType': actionType,
    'recipient': recipient,
    'subject': subject,
    'content': content,
    'auditRecord': auditRecord?.toJson(),
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory PendingApprovalAction.fromJson(Map<String, dynamic> json) => PendingApprovalAction(
    id: json['id'] as String? ?? '',
    actionType: json['actionType'] as String? ?? 'email',
    recipient: json['recipient'] as String? ?? '',
    subject: json['subject'] as String? ?? '',
    content: json['content'] as String? ?? '',
    status: ApprovalStatus.values.firstWhere(
      (e) => e.name == (json['status'] as String? ?? 'pending'),
      orElse: () => ApprovalStatus.pending,
    ),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Action Guardrail Manager enforcing Free-Run vs Approval-Required Tiers
class ActionGuardrailManager {
  static final ActionGuardrailManager _instance = ActionGuardrailManager._internal();
  factory ActionGuardrailManager() => _instance;
  ActionGuardrailManager._internal();

  static const String _pendingKey = 'aira_pending_approvals_v1';
  final Map<String, PendingApprovalAction> _pendingActions = {};

  /// Evaluates whether an action requires explicit human confirmation
  bool isApprovalRequired(String actionType) {
    final lower = actionType.toLowerCase().trim();
    const approvalTiers = {
      'send_email', 'email', 'email_send',
      'send_sms', 'sms', 'sms_send',
      'make_call', 'call', 'phone_call',
      'workspace_write', 'workspace_delete',
      'file_delete', 'delete_file',
      'spending', 'payment', 'transfer', 'payment_send', 'spending_action',
    };
    return approvalTiers.contains(lower);
  }

  /// Register a pending approval action and persist
  Future<PendingApprovalAction> createApprovalRequest({
    required String actionType,
    required String recipient,
    required String subject,
    required String content,
    SelfCheckAuditRecord? auditRecord,
  }) async {
    final id = 'appr_${DateTime.now().millisecondsSinceEpoch}';
    final action = PendingApprovalAction(
      id: id,
      actionType: actionType,
      recipient: recipient,
      subject: subject,
      content: content,
      auditRecord: auditRecord,
      status: ApprovalStatus.pending,
    );

    _pendingActions[id] = action;
    await _save();
    return action;
  }

  /// User approves the action
  Future<bool> approveAction(String id) async {
    final action = _pendingActions[id];
    if (action == null) return false;
    action.status = ApprovalStatus.approved;
    await _save();
    return true;
  }

  /// User rejects the action
  Future<bool> rejectAction(String id) async {
    final action = _pendingActions[id];
    if (action == null) return false;
    action.status = ApprovalStatus.rejected;
    await _save();
    return true;
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _pendingActions.values.map((a) => a.toJson()).toList();
      await prefs.setString(_pendingKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[GUARDRAIL] Failed to save pending approvals: $e');
    }
  }

  PendingApprovalAction? getPending(String id) => _pendingActions[id];
}
