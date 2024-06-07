import "dart:convert";
import "dart:ui";
import "package:flutter/material.dart";
import "package:intl/intl.dart";
import "package:weather_app/addition_info_item.dart";
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import "package:weather_app/secrets.dart";

import "hourly_forecast_item.dart";

class WeatherAppScreen extends StatefulWidget {
  const WeatherAppScreen({super.key});

  @override
  State<WeatherAppScreen> createState() => _WeatherAppScreenState();
}

class _WeatherAppScreenState extends State<WeatherAppScreen> {
  late Future<Map<String, dynamic>> weather;

  @override
  void initState() {
    super.initState();
    weather = getCurrentWeather();
  }

  Future<Map<String, dynamic>> getCurrentWeather() async {
    try {
      // Initialize the location plugin
      Location location = new Location();

      // Check if location services are enabled
      bool _serviceEnabled;
      PermissionStatus _permissionGranted;
      LocationData _locationData;

      _serviceEnabled = await location.serviceEnabled();
      if (!_serviceEnabled) {
        _serviceEnabled = await location.requestService();
        if (!_serviceEnabled) {
          return {'error': 'Location services are disabled.'};
        }
      }

      _permissionGranted = await location.hasPermission();
      if (_permissionGranted == PermissionStatus.denied) {
        _permissionGranted = await location.requestPermission();
        if (_permissionGranted != PermissionStatus.granted) {
          return {'error': 'Location permissions are denied.'};
        }
      }

      _locationData = await location.getLocation();

      // Use the latitude and longitude to get the city name
      String apiKey = '$openCageApiKey'; // Replace with your OpenCage API key
      String url =
          'https://api.opencagedata.com/geocode/v1/json?q=${_locationData.latitude}+${_locationData.longitude}&key=$apiKey';

      final res = await http.get(Uri.parse(url));

      final data = jsonDecode(res.body);

      if (data['results'].isEmpty) {
        throw 'City not found';
      }

      String cityName = data['results'][0]['components']['city'];

      final weatherRes = await http.get(
        Uri.parse(
            'https://api.openweathermap.org/data/2.5/forecast?q=$cityName&APPID=$openWeatherApiKey'),
      );

      final weatherData = jsonDecode(weatherRes.body);

      if (weatherData['cod'] != '200') {
        throw 'An unexpected error occurred';
      }

      return weatherData;
    } catch (e) {
      throw e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Weather App',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
                onPressed: () {
                  setState(() {
                    weather = getCurrentWeather();
                  });
                },
                icon: const Icon(Icons.refresh))
          ],
        ),
        body: FutureBuilder(
          future: weather,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator.adaptive(),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(snapshot.error.toString()),
              );
            }

            final data = snapshot.data!;
            final currentWeatherData = data['list'][0];
            final currentTemp = double.parse(
                    (currentWeatherData['main']['temp'] - 273.15).toString())
                .toStringAsFixed(2);
            final currentSkyApperance =
                currentWeatherData['weather'][0]['main'];
            final currentSkyApperanceDescription =
                currentWeatherData['weather'][0]['description'];

            final pressure = currentWeatherData['main']['pressure'];
            final windSpeed = currentWeatherData['wind']['speed'];
            final humidity = currentWeatherData['main']['humidity'];

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Weather Data
                    SizedBox(
                      width: double.infinity,
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 10,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  Text(
                                    '$currentTemp° C',
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(
                                    height: 16,
                                  ),
                                  currentSkyApperance == 'Clouds' ||
                                          currentSkyApperance == 'Clouds'
                                      ? const Icon(
                                          Icons.cloud,
                                          size: 64,
                                        )
                                      : const Icon(
                                          Icons.cloud,
                                          size: 64,
                                        ),
                                  const SizedBox(
                                    height: 16,
                                  ),
                                  Text(
                                    currentSkyApperance,
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    currentSkyApperanceDescription,
                                    style: const TextStyle(fontSize: 18),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    //Weather Forecast
                    const Text(
                      'Weather Forecast',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: 5,
                        itemBuilder: (context, index) {
                          final hourlyForecastIcon =
                              data['list'][index + 1]['weather'][0]['main'];
                          final hourlyForecastTime = DateTime.parse(
                              data['list'][index + 1]['dt_txt'].toString());
                          final hourlyForecastValue = double.parse((data['list']
                                          [index + 1]['main']['temp'] -
                                      273.15)
                                  .toString())
                              .toStringAsFixed(2);
                          return SizedBox(
                            width: 100,
                            child: HourlyForecastItem(
                              icon: hourlyForecastIcon == 'Clouds' ||
                                      hourlyForecastIcon == 'Rain'
                                  ? Icons.cloud
                                  : Icons.sunny,
                              time: DateFormat('j')
                                  .format(hourlyForecastTime)
                                  .toString(),
                              value: '$hourlyForecastValue° C',
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    //Additional Information
                    const Text(
                      'Additional Information',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        AdditionInfoItem(
                            icon: Icons.water_drop,
                            label: 'Humidity',
                            value: humidity.toString()),
                        AdditionInfoItem(
                            icon: Icons.air,
                            label: 'Wind Speed',
                            value: windSpeed.toString()),
                        AdditionInfoItem(
                            icon: Icons.beach_access,
                            label: 'Pressure',
                            value: pressure.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ));
  }
}
