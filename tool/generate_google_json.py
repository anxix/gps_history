"""Generates a Google JSON style history file for testing purposes."""

from math import sin, cos

# Configuration options

filename = r'google_history.json'
nr_points = 1000000
time_between_points_s = 60
start_time = 1379129160146  # in milliseconds sinde 1/1/9170 UTC


def accuracy_rule(index): return 20 * (index % 30)


def altitude_rule(index): return 300 * sin(index)


def latitude_rule(index): return 10000000 * 90 * sin(index / 1000)


def longitude_rule(index): return 10000000 * 180 * cos(index / 1000)


def time_activity_rule(index):
    return time_between_points_s // (1 + (index % 3))


def time_rule(index):
    extra_delay = 0 if index % 50 != 0 else time_between_points_s * \
        100 * (index % 10)
    return index * 1000 * time_between_points_s + extra_delay


def vertical_accuracy_rule(index):
    return accuracy_rule(index) // 10

# Implementation


pattern_accuracy_only = '''
        "timestampMs": "{time}",
        "latitudeE7": {latitude},
        "longitudeE7": {longitude},
        "accuracy": {accuracy}
'''

pattern_activity = '''
        "timestampMs": "{time}",
        "latitudeE7": {latitude},
        "longitudeE7": {longitude},
        "accuracy": {accuracy},
        "activity": [{{
            "timestampMs": "{time_activity}",
            "activity": [{{
                "type": "UNKNOWN",
                "confidence": 56
            }}, {{
                "type": "STILL",
                "confidence": 38
            }}, {{
                "type": "IN_VEHICLE",
                "confidence": 5
            }}, {{
                "type": "TILTING",
                "confidence": 1
            }}]
        }}]
'''

pattern_altitude = '''
        "timestampMs": "{time}",
        "latitudeE7": {latitude},
        "longitudeE7": {longitude},
        "accuracy": {accuracy},
        "altitude": {altitude},
        "verticalAccuracy": {vertical_accuracy}
'''

all_patterns = [pattern_accuracy_only, pattern_accuracy_only, pattern_altitude,
                pattern_accuracy_only, pattern_altitude, pattern_activity]
nr_patterns = len(all_patterns)

file = open(filename, 'w')

# Lead-in
file.write("""{
    "locations": [{""")

# Points
points_written = 0
while points_written < nr_points:
    # Select a pattern
    pattern = all_patterns[points_written % nr_patterns]

    # Calculate the things we may fill in
    time = round(start_time + time_rule(points_written))
    time_activity = round(time + time_activity_rule(points_written))
    s = pattern.format(
        time=time,
        time_activity=time_activity,
        latitude=round(latitude_rule(points_written)),
        longitude=round(longitude_rule(points_written)),
        accuracy=round(accuracy_rule(points_written)),
        altitude=round(altitude_rule(points_written)),
        vertical_accuracy=round(vertical_accuracy_rule(points_written)),
    )

    file.write(s)
    points_written += 1

    if points_written <= nr_points:
        file.write("    }, {")


# Lead-out
file.write("""
    }]
}""")
