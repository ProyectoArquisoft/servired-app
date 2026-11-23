/// Rutas de la app. Centralizadas para no repetir cadenas.
abstract final class Routes {
  static const home = '/';
  static const newOutage = '/reportes/nuevo';
  static const restoration = '/reportes/restablecimiento';
  static const myReports = '/reportes/mios';
  static const validate = '/validaciones';
  static const map = '/mapa';
  static const indicators = '/indicadores';
  static const fraud = '/fraude';
  static const login = '/ingresar';

  /// Rutas que exigen sesión (el contrato pide rol CIUDADANO). La denuncia de
  /// fraude y los indicadores son públicos.
  static const requiresLogin = {newOutage, restoration, validate, map, myReports};
}
