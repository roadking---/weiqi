maxmind = require('maxmind')

maxmind.init './GeoLiteCity.dat'
console.log maxmind.getLocation("119.254.243.114")

maxmind.init './GeoIP.dat'
console.log maxmind.getCountry("119.254.243.114")