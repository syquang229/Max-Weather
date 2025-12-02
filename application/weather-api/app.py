from flask import Flask, jsonify, request
from flask_cors import CORS
import logging
import sys
from datetime import datetime
import random
import os
import requests
from functools import lru_cache

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# OpenWeatherMap API Configuration
OPENWEATHER_API_KEY = os.environ.get('OPENWEATHER_API_KEY', '')
OPENWEATHER_BASE_URL = 'https://api.openweathermap.org/data/2.5'
USE_MOCK_DATA = os.environ.get('USE_MOCK_DATA', 'false').lower() == 'true'

# City name mapping for OpenWeatherMap
SUPPORTED_CITIES = {
    'New York': 'New York,US',
    'London': 'London,GB',
    'Tokyo': 'Tokyo,JP',
    'Sydney': 'Sydney,AU',
    'Paris': 'Paris,FR',
    'Los Angeles': 'Los Angeles,US',
    'Chicago': 'Chicago,US',
    'Houston': 'Houston,US',
    'Phoenix': 'Phoenix,US',
    'San Francisco': 'San Francisco,US',
    'Berlin': 'Berlin,DE',
    'Mumbai': 'Mumbai,IN',
    'Singapore': 'Singapore,SG',
    'Toronto': 'Toronto,CA',
    'Dubai': 'Dubai,AE'
}

# Mock weather data (fallback when API key not configured or USE_MOCK_DATA=true)
MOCK_WEATHER_DATA = {
    'New York': {
        'temperature': 72,
        'condition': 'Partly Cloudy',
        'humidity': 65,
        'wind_speed': 8,
        'forecast': [
            {'day': 'Monday', 'high': 75, 'low': 62, 'condition': 'Sunny'},
            {'day': 'Tuesday', 'high': 73, 'low': 60, 'condition': 'Cloudy'},
            {'day': 'Wednesday', 'high': 70, 'low': 58, 'condition': 'Rainy'},
        ]
    },
    'London': {
        'temperature': 59,
        'condition': 'Rainy',
        'humidity': 78,
        'wind_speed': 12,
        'forecast': [
            {'day': 'Monday', 'high': 62, 'low': 52, 'condition': 'Rainy'},
            {'day': 'Tuesday', 'high': 61, 'low': 51, 'condition': 'Cloudy'},
            {'day': 'Wednesday', 'high': 63, 'low': 53, 'condition': 'Partly Cloudy'},
        ]
    },
    'Tokyo': {
        'temperature': 68,
        'condition': 'Clear',
        'humidity': 60,
        'wind_speed': 6,
        'forecast': [
            {'day': 'Monday', 'high': 71, 'low': 58, 'condition': 'Clear'},
            {'day': 'Tuesday', 'high': 72, 'low': 59, 'condition': 'Sunny'},
            {'day': 'Wednesday', 'high': 70, 'low': 57, 'condition': 'Partly Cloudy'},
        ]
    },
    'Sydney': {
        'temperature': 77,
        'condition': 'Sunny',
        'humidity': 55,
        'wind_speed': 10,
        'forecast': [
            {'day': 'Monday', 'high': 80, 'low': 65, 'condition': 'Sunny'},
            {'day': 'Tuesday', 'high': 78, 'low': 64, 'condition': 'Partly Cloudy'},
            {'day': 'Wednesday', 'high': 76, 'low': 63, 'condition': 'Cloudy'},
        ]
    },
    'Paris': {
        'temperature': 64,
        'condition': 'Cloudy',
        'humidity': 70,
        'wind_speed': 9,
        'forecast': [
            {'day': 'Monday', 'high': 67, 'low': 54, 'condition': 'Cloudy'},
            {'day': 'Tuesday', 'high': 65, 'low': 53, 'condition': 'Partly Cloudy'},
            {'day': 'Wednesday', 'high': 68, 'low': 55, 'condition': 'Sunny'},
        ]
    }
}


@app.route('/', methods=['GET'])
def index():
    """
    API information endpoint
    """
    return jsonify({
        'api': 'Max Weather API',
        'version': '1.0.0',
        'description': 'Weather forecasting service',
        'endpoints': {
            '/health': 'Health check endpoint',
            '/ready': 'Readiness check endpoint',
            '/current?location={city}': 'Get current weather',
            '/forecast?location={city}&days={1-7}': 'Get weather forecast',
            '/cities': 'List available cities'
        },
        'external_api': 'OpenWeatherMap' if OPENWEATHER_API_KEY else 'Mock Data',
        'api_configured': bool(OPENWEATHER_API_KEY),
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/health', methods=['GET'])
def health():
    """
    Health check endpoint for Kubernetes liveness probe
    """
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/ready', methods=['GET'])
def ready():
    """
    Readiness check endpoint for Kubernetes readiness probe
    """
    # Check if we can connect to external API (if configured)
    ready = True
    message = 'ready'
    
    if OPENWEATHER_API_KEY and not USE_MOCK_DATA:
        try:
            # Quick health check to OpenWeatherMap
            response = requests.get(
                f"{OPENWEATHER_BASE_URL}/weather",
                params={'q': 'London', 'appid': OPENWEATHER_API_KEY},
                timeout=3
            )
            if response.status_code != 200:
                ready = False
                message = 'external API not accessible'
        except Exception as e:
            ready = False
            message = f'external API error: {str(e)}'
    
    status_code = 200 if ready else 503
    
    return jsonify({
        'status': 'ready' if ready else 'not ready',
        'message': message,
        'timestamp': datetime.utcnow().isoformat()
    }), status_code


@app.route('/startup', methods=['GET'])
def startup():
    """
    Startup check endpoint for Kubernetes startup probe
    """
    return jsonify({
        'status': 'started',
        'timestamp': datetime.utcnow().isoformat()
    }), 200


@app.route('/current', methods=['GET'])
def get_current_weather():
    """
    Get current weather for a location from OpenWeatherMap API
    Query params: location (required)
    """
    location = request.args.get('location', '').title()
    
    logger.info(f"Current weather request for location: {location}")
    
    if not location:
        logger.warning("Missing location parameter")
        return jsonify({
            'error': 'Missing required parameter: location'
        }), 400
    
    if location not in SUPPORTED_CITIES:
        logger.warning(f"Location not supported: {location}")
        return jsonify({
            'error': f'Location not supported: {location}',
            'available_locations': list(SUPPORTED_CITIES.keys())
        }), 404
    
    try:
        # Use mock data if configured or if API key not available
        if USE_MOCK_DATA or not OPENWEATHER_API_KEY:
            if not OPENWEATHER_API_KEY:
                logger.warning("OpenWeatherMap API key not configured, using mock data")
            weather = get_mock_weather(location)
        else:
            weather = fetch_current_weather(location)
        
        response = {
            'location': location,
            'current': weather,
            'timestamp': datetime.utcnow().isoformat(),
            'source': 'mock' if (USE_MOCK_DATA or not OPENWEATHER_API_KEY) else 'openweathermap'
        }
        
        logger.info(f"Returning weather data for {location}")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error fetching weather data: {str(e)}")
        return jsonify({
            'error': 'Failed to fetch weather data',
            'message': str(e)
        }), 500


@app.route('/forecast', methods=['GET'])
def get_forecast():
    """
    Get weather forecast for a location from OpenWeatherMap API
    Query params: location (required), days (optional, default=3, max=7)
    """
    location = request.args.get('location', '').title()
    days = request.args.get('days', '3')
    
    logger.info(f"Forecast request for location: {location}, days: {days}")
    
    try:
        days = int(days)
        if days < 1 or days > 7:
            raise ValueError("Days must be between 1 and 7")
    except ValueError as e:
        logger.warning(f"Invalid days parameter: {days}")
        return jsonify({
            'error': f'Invalid days parameter: {str(e)}'
        }), 400
    
    if not location:
        logger.warning("Missing location parameter")
        return jsonify({
            'error': 'Missing required parameter: location'
        }), 400
    
    if location not in SUPPORTED_CITIES:
        logger.warning(f"Location not supported: {location}")
        return jsonify({
            'error': f'Location not supported: {location}',
            'available_locations': list(SUPPORTED_CITIES.keys())
        }), 404
    
    try:
        # Use mock data if configured or if API key not available
        if USE_MOCK_DATA or not OPENWEATHER_API_KEY:
            if not OPENWEATHER_API_KEY:
                logger.warning("OpenWeatherMap API key not configured, using mock data")
            forecast = get_mock_forecast(location, days)
        else:
            forecast = fetch_forecast(location, days)
        
        response = {
            'location': location,
            'forecast': forecast,
            'days': len(forecast),
            'timestamp': datetime.utcnow().isoformat(),
            'source': 'mock' if (USE_MOCK_DATA or not OPENWEATHER_API_KEY) else 'openweathermap'
        }
        
        logger.info(f"Returning {len(forecast)}-day forecast for {location}")
        return jsonify(response), 200
        
    except Exception as e:
        logger.error(f"Error fetching forecast data: {str(e)}")
        return jsonify({
            'error': 'Failed to fetch forecast data',
            'message': str(e)
        }), 500


@app.route('/cities', methods=['GET'])
def get_cities():
    """
    Get list of available cities
    """
    logger.info("Cities list requested")
    
    cities = list(SUPPORTED_CITIES.keys())
    
    response = {
        'cities': cities,
        'count': len(cities),
        'api_configured': bool(OPENWEATHER_API_KEY),
        'using_mock_data': USE_MOCK_DATA or not OPENWEATHER_API_KEY
    }
    
    return jsonify(response), 200


# Helper functions for OpenWeatherMap API integration

@lru_cache(maxsize=100)
def fetch_current_weather(city):
    """
    Fetch current weather from OpenWeatherMap API
    Results are cached for performance
    """
    city_query = SUPPORTED_CITIES.get(city, city)
    
    url = f"{OPENWEATHER_BASE_URL}/weather"
    params = {
        'q': city_query,
        'appid': OPENWEATHER_API_KEY,
        'units': 'imperial'  # Fahrenheit
    }
    
    logger.info(f"Fetching current weather from OpenWeatherMap for {city}")
    response = requests.get(url, params=params, timeout=10)
    response.raise_for_status()
    
    data = response.json()
    
    return {
        'temperature': round(data['main']['temp'], 1),
        'condition': data['weather'][0]['main'],
        'description': data['weather'][0]['description'],
        'humidity': data['main']['humidity'],
        'wind_speed': round(data['wind']['speed'], 1),
        'pressure': data['main']['pressure'],
        'feels_like': round(data['main']['feels_like'], 1)
    }


@lru_cache(maxsize=100)
def fetch_forecast(city, days=3):
    """
    Fetch weather forecast from OpenWeatherMap API
    Results are cached for performance
    """
    city_query = SUPPORTED_CITIES.get(city, city)
    
    url = f"{OPENWEATHER_BASE_URL}/forecast"
    params = {
        'q': city_query,
        'appid': OPENWEATHER_API_KEY,
        'units': 'imperial',  # Fahrenheit
        'cnt': days * 8  # 8 forecasts per day (3-hour intervals)
    }
    
    logger.info(f"Fetching {days}-day forecast from OpenWeatherMap for {city}")
    response = requests.get(url, params=params, timeout=10)
    response.raise_for_status()
    
    data = response.json()
    
    # Group forecasts by day
    daily_forecasts = []
    current_day = None
    day_data = {'temps': [], 'conditions': []}
    
    for item in data['list']:
        dt = datetime.fromtimestamp(item['dt'])
        day_name = dt.strftime('%A')
        
        if current_day != day_name:
            if current_day is not None:
                # Save previous day
                daily_forecasts.append({
                    'day': current_day,
                    'high': round(max(day_data['temps']), 1),
                    'low': round(min(day_data['temps']), 1),
                    'condition': max(set(day_data['conditions']), key=day_data['conditions'].count)
                })
            
            current_day = day_name
            day_data = {'temps': [], 'conditions': []}
        
        day_data['temps'].append(item['main']['temp'])
        day_data['conditions'].append(item['weather'][0]['main'])
    
    # Add last day
    if current_day and day_data['temps']:
        daily_forecasts.append({
            'day': current_day,
            'high': round(max(day_data['temps']), 1),
            'low': round(min(day_data['temps']), 1),
            'condition': max(set(day_data['conditions']), key=day_data['conditions'].count)
        })
    
    return daily_forecasts[:days]


def get_mock_weather(city):
    """
    Get mock weather data for testing
    """
    if city in MOCK_WEATHER_DATA:
        weather = MOCK_WEATHER_DATA[city]
        return {
            'temperature': weather['temperature'],
            'condition': weather['condition'],
            'humidity': weather['humidity'],
            'wind_speed': weather['wind_speed']
        }
    else:
        # Generate random data for unsupported cities
        return {
            'temperature': random.randint(50, 85),
            'condition': random.choice(['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy']),
            'humidity': random.randint(40, 90),
            'wind_speed': random.randint(5, 20)
        }


def get_mock_forecast(city, days):
    """
    Get mock forecast data for testing
    """
    if city in MOCK_WEATHER_DATA:
        forecast = MOCK_WEATHER_DATA[city]['forecast']
        return forecast[:days]
    else:
        # Generate random forecast
        return [
            {
                'day': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][i % 5],
                'high': random.randint(70, 90),
                'low': random.randint(50, 65),
                'condition': random.choice(['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy'])
            }
            for i in range(days)
        ]


if __name__ == '__main__':
    logger.info("Starting Weather API application")
    logger.info(f"OpenWeatherMap API configured: {bool(OPENWEATHER_API_KEY)}")
    logger.info(f"Using mock data: {USE_MOCK_DATA or not OPENWEATHER_API_KEY}")
    app.run(host='0.0.0.0', port=8080, debug=False)
