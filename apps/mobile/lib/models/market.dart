/// Countries Voffer runs in. Each shop is in one, and its prices are in that
/// country's currency.
enum Country {
  india('IN', 'India', 'INR'),
  usa('US', 'USA', 'USD');

  const Country(this.code, this.label, this.currency);

  /// ISO 3166 code stored in the database.
  final String code;
  final String label;

  /// ISO 4217 code prices are shown in.
  final String currency;

  static Country fromCode(String? code) =>
      values.firstWhere((c) => c.code == code, orElse: () => Country.india);

  /// A rough guess from a map position: the Americas are the USA, anywhere
  /// else India. Firms can change it.
  static Country near(double lng) => lng < -30 ? Country.usa : Country.india;
}
