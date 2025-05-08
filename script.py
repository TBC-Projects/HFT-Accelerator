import requests

API_KEY = '5nMOblcaLluhVKAoAKTBbrrhLzx2D774'
TICKER = 'MSFT'
url = f"https://api.polygon.io/v2/aggs/ticker/{TICKER}/prev?adjusted=true&apiKey={API_KEY}"
response = requests.get(url)

if response.status_code == 200:
    data = response.json()
    price = bin(int(data['results'][0]['c'] * 100))[2:]
    print(f" {TICKER}: {price}")
else:
    print("Error:", response.status_code, response.text)
