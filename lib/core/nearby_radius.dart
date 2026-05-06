const defaultNearbyRadiusMiles = 50.0;
const minimumNearbyRadiusMiles = 1.0;
const maximumNearbyRadiusMiles = 150.0;
const kilometersPerMile = 1.609344;

double milesToKilometers(double miles) => miles * kilometersPerMile;
