import requests
import json

url = 'https://tesing.mtltechnical.co.za/mobile/add_learner.php'

print("Testing add_learner.php endpoint...")
print(f"URL: {url}\n")

# Test with GET request first
try:
    response = requests.get(url, timeout=10, verify=False)
    print(f"GET HTTP Status Code: {response.status_code}")
    print(f"GET Response: {response.text[:200]}...")
except Exception as e:
    print(f"GET Error: {e}")

print("\n--- Testing POST request ---")

# Test with POST request
test_data = {
    'classID': 'TEST',
    'Name': 'Test',
    'Surname': 'User'
}

try:
    response = requests.post(
        url, 
        json=test_data,
        headers={'Content-Type': 'application/json'},
        timeout=10,
        verify=False
    )
    print(f"POST HTTP Status Code: {response.status_code}")
    print(f"POST Response: {response.text[:200]}...")
except Exception as e:
    print(f"POST Error: {e}")