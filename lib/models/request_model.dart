enum RequestStatus { pending, accepted, rejected, timeout }

class RequestModel {
  final String requestId;
  final String hospitalId;
  final String caseId;
  RequestStatus status;

  RequestModel({
    required this.requestId,
    required this.hospitalId,
    required this.caseId,
    this.status = RequestStatus.pending,
  });

  factory RequestModel.fromJson(Map<String, dynamic> json) {
    return RequestModel(
      requestId: json['_id'] ?? '',
      hospitalId: json['hospitalId'] ?? '',
      caseId: json['caseId'] ?? '',
      status: _parseStatus(json['status']),
    );
  }

  static RequestStatus _parseStatus(String? raw) {
    switch (raw) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      case 'timeout':
        return RequestStatus.timeout;
      default:
        return RequestStatus.pending;
    }
  }
}
