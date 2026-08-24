/// 出口 IP 信息（异步获取，结果用于首页 IP 信息卡片）。
class IpInfo {
  final String countryCode; // e.g. "HK"
  final String countryName; // e.g. "Hong Kong"
  final String ip;
  final String asn; // 自治域编号 e.g. "AS4760"
  final String isp; // 服务商
  final String org; // 组织
  final String timezone; // e.g. "Asia/Hong_Kong"
  final double? lat; // 纬度（首页右下角显示）
  final double? lng; // 经度
  final DateTime? fetchedAt;
  final bool loading;
  final String? error;

  const IpInfo({
    this.countryCode = '',
    this.countryName = '',
    this.ip = '',
    this.asn = '',
    this.isp = '',
    this.org = '',
    this.timezone = '',
    this.lat,
    this.lng,
    this.fetchedAt,
    this.loading = false,
    this.error,
  });

  IpInfo copyWith({
    String? countryCode,
    String? countryName,
    String? ip,
    String? asn,
    String? isp,
    String? org,
    String? timezone,
    double? lat,
    double? lng,
    bool? loading,
    String? error,
    DateTime? fetchedAt,
  }) => IpInfo(
    countryCode: countryCode ?? this.countryCode,
    countryName: countryName ?? this.countryName,
    ip: ip ?? this.ip,
    asn: asn ?? this.asn,
    isp: isp ?? this.isp,
    org: org ?? this.org,
    timezone: timezone ?? this.timezone,
    lat: lat ?? this.lat,
    lng: lng ?? this.lng,
    loading: loading ?? this.loading,
    error: error,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );

  bool get isEmpty =>
      countryCode.isEmpty &&
      ip.isEmpty &&
      asn.isEmpty &&
      isp.isEmpty &&
      org.isEmpty &&
      !loading &&
      error == null;
}
