import 'dart:convert';

import 'package:http/http.dart' as http;

class City {
  const City({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.latitude,
    required this.longitude,
    required this.photo,
  });
  final String id;
  final String name;
  final String nameEn;
  final double latitude;
  final double longitude;
  final String photo;
}

class HourlyWx {
  const HourlyWx(this.time, this.temp, this.code);
  final String time;
  final int temp;
  final int code;
}

class DailyWx {
  const DailyWx(this.date, this.high, this.low, this.code);
  final String date;
  final int high;
  final int low;
  final int code;
}

class WeatherSnap {
  const WeatherSnap({
    required this.temp,
    required this.high,
    required this.low,
    required this.code,
    required this.humidity,
    required this.wind,
    required this.uv,
    required this.apparent,
    required this.hourly,
    required this.daily,
    required this.cachedAt,
    this.clouds = 0,
  });
  final int temp;
  final int high;
  final int low;
  final int code;
  final int humidity;
  final double wind;
  final double uv;
  final int apparent;
  final List<HourlyWx> hourly;
  final List<DailyWx> daily;
  final String cachedAt;
  final int clouds;
}

const cities = [
  City(id: 'phnom-penh', name: 'ភ្នំពេញ', nameEn: 'Phnom Penh', latitude: 11.5564, longitude: 104.9282, photo: 'assets/weather/phnom-penh.jpg'),
  City(id: 'banteay-meanchey', name: 'បន្ទាយមានជ័យ', nameEn: 'Banteay Meanchey', latitude: 13.5859, longitude: 102.9737, photo: 'assets/weather/banteay.jpg'),
  City(id: 'battambang', name: 'បាត់ដំបង', nameEn: 'Battambang', latitude: 13.0957, longitude: 103.2022, photo: 'assets/weather/battambang.jpg'),
  City(id: 'kampong-cham', name: 'កំពង់ចាម', nameEn: 'Kampong Cham', latitude: 11.9934, longitude: 105.4635, photo: 'assets/weather/kampong-cham.jpg'),
  City(id: 'kampong-chhnang', name: 'កំពង់ឆ្នាំង', nameEn: 'Kampong Chhnang', latitude: 12.25, longitude: 104.6667, photo: 'assets/weather/kampot.jpg'),
  City(id: 'kampong-speu', name: 'កំពង់ស្ពឺ', nameEn: 'Kampong Speu', latitude: 11.4533, longitude: 104.519, photo: 'assets/weather/kampot.jpg'),
  City(id: 'kampong-thom', name: 'កំពង់ធំ', nameEn: 'Kampong Thom', latitude: 12.7111, longitude: 104.8889, photo: 'assets/weather/banteay.jpg'),
  City(id: 'kampot', name: 'កំពត', nameEn: 'Kampot', latitude: 10.6104, longitude: 104.181, photo: 'assets/weather/kampot-river.jpg'),
  City(id: 'kandal', name: 'កណ្ដាល', nameEn: 'Kandal', latitude: 11.4833, longitude: 104.95, photo: 'assets/weather/phnom-penh-alt.jpg'),
  City(id: 'koh-kong', name: 'កោះកុង', nameEn: 'Koh Kong', latitude: 11.6153, longitude: 102.9839, photo: 'assets/weather/sihanoukville.jpg'),
  City(id: 'kratie', name: 'ក្រចេះ', nameEn: 'Kratie', latitude: 12.4881, longitude: 106.0188, photo: 'assets/weather/kratie.jpg'),
  City(id: 'mondulkiri', name: 'មណ្ឌលគិរី', nameEn: 'Mondulkiri', latitude: 12.4558, longitude: 107.1906, photo: 'assets/weather/mondulkiri.jpg'),
  City(id: 'pailin', name: 'ប៉ៃលិន', nameEn: 'Pailin', latitude: 12.8489, longitude: 102.6093, photo: 'assets/weather/battambang.jpg'),
  City(id: 'preah-vihear', name: 'ព្រះវិហារ', nameEn: 'Preah Vihear', latitude: 13.807, longitude: 104.978, photo: 'assets/weather/preah-vihear.jpg'),
  City(id: 'prey-veng', name: 'ព្រៃវែង', nameEn: 'Prey Veng', latitude: 11.485, longitude: 105.325, photo: 'assets/weather/kampong-cham.jpg'),
  City(id: 'pursat', name: 'ពោធិ៍សាត់', nameEn: 'Pursat', latitude: 12.5388, longitude: 103.9192, photo: 'assets/weather/kampot.jpg'),
  City(id: 'ratanakiri', name: 'រតនគិរី', nameEn: 'Ratanakiri', latitude: 13.7395, longitude: 106.9873, photo: 'assets/weather/mondulkiri.jpg'),
  City(id: 'siem-reap', name: 'សៀមរាប', nameEn: 'Siem Reap', latitude: 13.3633, longitude: 103.8564, photo: 'assets/weather/siem-reap.jpg'),
  City(id: 'sihanoukville', name: 'ព្រះសីហនុ', nameEn: 'Sihanoukville', latitude: 10.6271, longitude: 103.5222, photo: 'assets/weather/sihanoukville.jpg'),
  City(id: 'stung-treng', name: 'ស្ទឹងត្រែង', nameEn: 'Stung Treng', latitude: 13.5259, longitude: 105.9683, photo: 'assets/weather/kratie.jpg'),
  City(id: 'svay-rieng', name: 'ស្វាយរៀង', nameEn: 'Svay Rieng', latitude: 11.0879, longitude: 105.7993, photo: 'assets/weather/kampong-cham.jpg'),
  City(id: 'takeo', name: 'តាកែវ', nameEn: 'Takeo', latitude: 10.9908, longitude: 104.785, photo: 'assets/weather/kampot-river.jpg'),
  City(id: 'oddar-meanchey', name: 'ឧត្តរមានជ័យ', nameEn: 'Oddar Meanchey', latitude: 14.1817, longitude: 103.5176, photo: 'assets/weather/banteay.jpg'),
  City(id: 'kep', name: 'កែប', nameEn: 'Kep', latitude: 10.4826, longitude: 104.3167, photo: 'assets/weather/sihanoukville.jpg'),
  City(id: 'tboung-khmum', name: 'ត្បូងឃ្មុំ', nameEn: 'Tboung Khmum', latitude: 11.911, longitude: 105.658, photo: 'assets/weather/kampong-cham.jpg'),
];

City? cityById(String id) {
  for (final c in cities) {
    if (c.id == id) return c;
  }
  return null;
}

City nearestCity(double lat, double lon) {
  var best = cities.first;
  var dist = double.infinity;
  for (final c in cities) {
    final d = (c.latitude - lat) * (c.latitude - lat) + (c.longitude - lon) * (c.longitude - lon);
    if (d < dist) {
      dist = d;
      best = c;
    }
  }
  return best;
}

class WxMeta {
  const WxMeta(this.en, this.km, this.kind);
  final String en;
  final String km;
  final String kind;
}

WxMeta wmoOf(int code) {
  if (code <= 0) return const WxMeta('clear sky', 'ថ្ងៃថ្លា', 'clear');
  if (code <= 1) return const WxMeta('mainly clear', 'ស្ទើរតែថ្លា', 'clear');
  if (code <= 2) return const WxMeta('partly cloudy', 'មានពពកបន្តិច', 'cloudy');
  if (code <= 3) return const WxMeta('overcast clouds', 'ពពកអស់មេឃ', 'cloudy');
  if (code <= 48) return const WxMeta('fog', 'អ័ព្ទ', 'cloudy');
  if (code <= 57) return const WxMeta('drizzle', 'ភ្លៀងសើម', 'rain');
  if (code <= 67) return const WxMeta('rain', 'ភ្លៀង', 'rain');
  if (code <= 77) return const WxMeta('snow', 'ព្រិល', 'rain');
  if (code <= 82) return const WxMeta('rain showers', 'ភ្លៀងផ្កាឈូក', 'rain');
  if (code <= 86) return const WxMeta('snow showers', 'ព្រិល', 'rain');
  return const WxMeta('thunderstorm', 'ព្យុះផ្គររន្ទះ', 'storm');
}

String wmoIconUrl(int code) {
  final icon =
      code <= 1
          ? '01d'
          : code <= 2
              ? '02d'
              : code <= 3
                  ? '04d'
                  : code <= 48
                      ? '50d'
                      : code <= 57
                          ? '09d'
                          : code <= 67
                              ? '10d'
                              : code <= 77
                                  ? '13d'
                                  : code <= 82
                                      ? '09d'
                                      : code <= 86
                                          ? '13d'
                                          : '11d';
  return 'https://openweathermap.org/img/wn/$icon@2x.png';
}

const _wikiHeaders = {
  'User-Agent': 'KhmerCalendar/1.0 (https://khmercalendar.pages.dev)',
  'Accept': 'application/json',
};

final _photoMem = <String, String?>{};

/// Forgets the city photo addresses kept in memory; they are looked up again when needed.
void clearWeatherMemoryCache() => _photoMem.clear();



const _photoOverrides = <String, String>{};



final _badPhotoName = RegExp(
  r'(sign|welcome|logo|map|flag|seal|stamp|coat[ _]of|banner|poster|diagram|chart|billboard|screenshot|locator'
  r'|monument|memorial|statue|temple|pagoda|wat[ _]|angkor|palace|museum|church|mosque|shrine|stupa|building'
  r'|hotel|resort|school|university|stadium|airport|station|office|hall|gate|crab|portrait|people|food|market|logo)',
  caseSensitive: false,
);


final _goodPhotoName = RegExp(
  r'(landscape|scenery|view|rice|paddy|field|river|mekong|lake|beach|coast|sea|island|mountain|hill|forest|jungle|'
  r'waterfall|sunset|sunrise|sky|farm|countryside|bay|mangrove|plantation)',
  caseSensitive: false,
);

Uri _commonsUri(Map<String, String> q) => Uri.https('commons.wikimedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'origin': '*',
      'prop': 'imageinfo',
      'iiprop': 'url|size|mime',
      'iiurlwidth': '1200',
      ...q,
    });

Future<Map<String, dynamic>?> _getJson(Uri url) async {
  final res = await http.get(url, headers: _wikiHeaders).timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) return null;
  return jsonDecode(res.body) as Map<String, dynamic>;
}


String? _bestCommonsPhoto(Map<String, dynamic>? j) {
  final pages = (j?['query']?['pages'] as Map<String, dynamic>?)?.values.toList();
  if (pages == null || pages.isEmpty) return null;
  String? best;
  var bestScore = -1;
  for (final p in pages) {
    final title = (p['title'] ?? '') as String;
    final info = (p['imageinfo'] as List?)?.firstOrNull as Map<String, dynamic>?;
    if (info == null || _badPhotoName.hasMatch(title)) continue;
    if (info['mime'] != 'image/jpeg') continue;
    final w = (info['width'] ?? 0) as num;
    final h = (info['height'] ?? 0) as num;
    if (w < 1600 || h <= 0) continue;
    final ratio = w / h;
    if (ratio < 1.2 || ratio > 2.2) continue;
    final url = (info['thumburl'] ?? info['url']) as String?;
    if (url == null || url.isEmpty) continue;

    final score = (_goodPhotoName.hasMatch(title) ? 1000 : 0) - ((p['index'] ?? 0) as num).toInt();
    if (score > bestScore) {
      bestScore = score;
      best = url;
    }
  }
  return best;
}



Future<String?> _photoFromSearch(City city) async {
  final queries = [
    '${city.nameEn} Cambodia landscape',
    '${city.nameEn} province Cambodia rice field river',
    '${city.nameEn} Cambodia view',
  ];
  for (final q in queries) {
    final j = await _getJson(_commonsUri({
      'generator': 'search',
      'gsrnamespace': '6',
      'gsrsearch': '$q filetype:bitmap',
      'gsrlimit': '40',
    }));
    final url = _bestCommonsPhoto(j);
    if (url != null) return url;
  }
  return null;
}

Future<String?> _photoFromOverride(String fileTitle) async {
  final j = await _getJson(_commonsUri({'titles': fileTitle}));
  final pages = (j?['query']?['pages'] as Map<String, dynamic>?)?.values.toList();
  final info = (pages?.firstOrNull?['imageinfo'] as List?)?.firstOrNull as Map<String, dynamic>?;
  return (info?['thumburl'] ?? info?['url']) as String?;
}



Future<String?> _photoFromGeosearch(City city) async {
  final j = await _getJson(_commonsUri({
    'generator': 'geosearch',
    'ggsnamespace': '6',
    'ggscoord': '${city.latitude}|${city.longitude}',
    'ggsradius': '10000',
    'ggslimit': '50',
  }));
  return _bestCommonsPhoto(j);
}

Future<String?> _photoFromWikipedia(City city) async {
  final j = await _getJson(Uri.parse(
    'https://en.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(city.nameEn)}',
  ));
  final orig = j?['originalimage'] as Map<String, dynamic>?;
  final src = (orig?['source'] ?? j?['thumbnail']?['source']) as String?;
  if (src == null || _badPhotoName.hasMatch(Uri.decodeComponent(src))) return null;
  final w = (orig?['width'] ?? 0) as num;
  final h = (orig?['height'] ?? 0) as num;
  if (h <= 0 || w / h < 1.2) return null;
  return src;
}

Future<String?> cityPhotoUrl(City city) async {
  final cached = _photoMem[city.id];
  if (cached != null) return cached;
  String? url;
  try {
    final fixed = _photoOverrides[city.id];
    if (fixed != null) url = await _photoFromOverride(fixed);
    url ??= await _photoFromSearch(city);
    url ??= await _photoFromGeosearch(city);
    url ??= await _photoFromWikipedia(city);
  } catch (_) {}
  if (url != null) _photoMem[city.id] = url;
  return url;
}

Future<WeatherSnap> fetchWeather(City city) async {
  final url = Uri.parse(
    'https://api.open-meteo.com/v1/forecast?latitude=${city.latitude}&longitude=${city.longitude}'
    '&current=temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m,apparent_temperature,uv_index,cloud_cover'
    '&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=Asia%2FPhnom_Penh',
  );
  final res = await http.get(url).timeout(const Duration(seconds: 10));
  if (res.statusCode != 200) throw Exception('Http ${res.statusCode}');
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  final hourlyTimes = (j['hourly']?['time'] as List?) ?? [];
  final dailyTimes = (j['daily']?['time'] as List?) ?? [];
  final hourly = <HourlyWx>[];
  for (var i = 0; i < hourlyTimes.length && i < 12; i++) {
    hourly.add(HourlyWx(
      hourlyTimes[i] as String,
      ((j['hourly']['temperature_2m'][i] as num).round()),
      (j['hourly']['weather_code'][i] as num).toInt(),
    ));
  }
  final daily = <DailyWx>[];
  for (var i = 0; i < dailyTimes.length && i < 7; i++) {
    daily.add(DailyWx(
      dailyTimes[i] as String,
      (j['daily']['temperature_2m_max'][i] as num).round(),
      (j['daily']['temperature_2m_min'][i] as num).round(),
      (j['daily']['weather_code'][i] as num).toInt(),
    ));
  }
  final current = j['current'] as Map<String, dynamic>;
  return WeatherSnap(
    temp: (current['temperature_2m'] as num).round(),
    high: daily.isNotEmpty ? daily.first.high : (current['temperature_2m'] as num).round(),
    low: daily.isNotEmpty ? daily.first.low : (current['temperature_2m'] as num).round(),
    code: (current['weather_code'] as num).toInt(),
    humidity: (current['relative_humidity_2m'] as num).round(),
    wind: (current['wind_speed_10m'] as num).toDouble(),
    uv: (current['uv_index'] as num?)?.toDouble() ?? 0,
    apparent: (current['apparent_temperature'] as num).round(),
    hourly: hourly,
    daily: daily,
    cachedAt: DateTime.now().toIso8601String(),
    clouds: (current['cloud_cover'] as num?)?.round() ?? 0,
  );
}
