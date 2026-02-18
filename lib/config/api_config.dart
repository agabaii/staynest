class ApiConfig {
  // Если сервер запущен на том же компьютере, где и эмулятор/браузер, используй localhost
  // Если запускаешь на реальном iPhone, замени localhost на IP своего компьютера (например, 192.168.1.10)
  static const String baseUrl = 'http://192.168.8.96:8001/api';
  
  // Метод для получения полного URL (полезно для картинок)
  static String getBaseUrl() => baseUrl.replaceAll('/api', '');
}
