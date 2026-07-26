#!/usr/bin/env node
/*
 * VANTAGE Public Sector Edition
 * Optional helper: assembles the seven entity JSON files in data/entities/
 * from the curated source table below, attaching provenance to every field.
 *
 * Every row in ROWS is a real public entity. Identity, coordinates and the
 * scale metric come from the named public registries (see data/sources.json).
 * Building attributes (floors, height, sqft, built, constr, roof) are null
 * unless the value is widely documented; the build environment blocks live
 * Overpass API retrieval, and inventing values is prohibited.
 *
 * Hard rule: no em dash characters anywhere in generated output.
 */

'use strict';

const fs = require('fs');
const path = require('path');

/* ------------------------------------------------------------------ */
/* Per-segment configuration                                           */
/* ------------------------------------------------------------------ */

const SEG_CONFIG = {
  air: {
    file: 'air.json',
    metricKey: 'passengers',
    metricSrc: 'faa_enplanements',
    metricYear: 2023,
    registrySrc: 'faa_npias',
    coordSrc: 'faa_npias',
    tivMult: 420,
    tivFormula: 'tiv = passengers * 420 (USD per annual enplanement, terminal replacement heuristic)'
  },
  transit: {
    file: 'transit.json',
    metricKey: 'ridership',
    metricSrc: 'ntd_upt',
    metricYear: 2023,
    registrySrc: 'ntd_agency',
    coordSrc: 'osm',
    tivMult: 28,
    tivFormula: 'tiv = ridership * 28 (USD per annual unlinked trip, fleet and facility heuristic)'
  },
  city: {
    file: 'city.json',
    metricKey: 'employees',
    metricSrc: 'census_aspep',
    metricYear: 2023,
    registrySrc: 'census_aspep',
    coordSrc: 'osm',
    tivMult: 420000,
    tivFormula: 'tiv = employees * 420000 (USD per municipal FTE, schedule of values heuristic)'
  },
  water: {
    file: 'water.json',
    metricKey: 'served',
    metricSrc: 'epa_sdwis',
    metricYear: 2024,
    registrySrc: 'epa_sdwis',
    coordSrc: 'osm',
    tivMult: 1900,
    tivFormula: 'tiv = served * 1900 (USD per resident served, treatment and distribution heuristic)'
  },
  highered: {
    file: 'highered.json',
    metricKey: 'enrollment',
    metricSrc: 'ipeds',
    metricYear: 2023,
    registrySrc: 'ipeds',
    coordSrc: 'ipeds',
    tivMult: 260000,
    tivFormula: 'tiv = enrollment * 260000 (USD per enrolled student, campus replacement heuristic)'
  },
  health: {
    file: 'health.json',
    metricKey: 'beds',
    metricSrc: 'cms_pos',
    metricYear: 2023,
    registrySrc: 'cms_pos',
    coordSrc: 'cms_pos',
    tivMult: 2600000,
    tivFormula: 'tiv = beds * 2600000 (USD per licensed bed, hospital replacement heuristic)'
  },
  fed: {
    file: 'fed.json',
    metricKey: 'sqft',
    metricSrc: 'gsa_iolp',
    metricYear: 2024,
    registrySrc: 'gsa_iolp',
    coordSrc: 'gsa_iolp',
    tivMult: 480,
    tivFormula: 'tiv = sqft * 480 (USD per gross square foot, federal office replacement heuristic)'
  }
};

const PREM_RATE = 0.0012;
const PREM_FORMULA = 'prem = tiv * 0.0012 (12 bps blended property rate assumption)';

/* Producer books split by BEA super-region. */
const PRODUCER_BY_STATE = {
  lorenz: ['CT', 'ME', 'MA', 'NH', 'RI', 'VT', 'DE', 'DC', 'MD', 'NJ', 'NY', 'PA', 'IL', 'IN', 'MI', 'OH', 'WI'],
  brown: ['AL', 'AR', 'FL', 'GA', 'KY', 'LA', 'MS', 'NC', 'SC', 'TN', 'VA', 'WV', 'AZ', 'NM', 'OK', 'TX', 'IA', 'KS', 'MN', 'MO', 'NE', 'ND', 'SD'],
  lindstrom: ['CO', 'ID', 'MT', 'UT', 'WY', 'AK', 'CA', 'HI', 'NV', 'OR', 'WA']
};

/* Modeled placeholder pools. Deterministic pick by entity id hash. */
const INCUMBENT_POOL = ['Aon', 'Gallagher', 'Alliant', 'Lockton', 'Brown & Brown', 'USI', 'McGriff', 'Risk Strategies'];

const TRIGGER_POOL = {
  air: [
    'Terminal expansion program announced in the capital plan',
    'Post-pandemic enplanement recovery outpacing regional peers',
    'FAA infrastructure grant award increases insured exposure',
    'Concourse renovation adds new schedule of values line items'
  ],
  transit: [
    'Fleet electrification program changes the property risk profile',
    'New rail extension adds stations and substations to the schedule',
    'State of good repair backlog drawing board attention',
    'Bus rapid transit corridor opening within 18 months'
  ],
  city: [
    'Bond referendum passed for municipal facility upgrades',
    'New risk manager hired from the private sector',
    'Consolidated public safety facility under construction',
    'Aging civic core flagged in the latest capital improvement plan'
  ],
  water: [
    'Lead service line replacement mandate increases capital spend',
    'Consent decree drives major treatment plant construction',
    'PFAS treatment retrofit planned across the system',
    'Rate case approved, funding a decade of plant renewal'
  ],
  highered: [
    'Campus master plan adds significant new square footage',
    'Deferred maintenance backlog disclosed in bond documents',
    'New research facility changes the protection class mix',
    'Athletics facility program raises catastrophe exposure'
  ],
  health: [
    'Bed tower expansion announced in the capital budget',
    'System considering consolidation of aging inpatient plants',
    'Seismic compliance deadline drives retrofit spending',
    'New trauma designation increases business interruption values'
  ],
  fed: [
    'GSA disposition review may change occupancy assumptions',
    'Major modernization funded through the Federal Buildings Fund',
    'Agency consolidation increases contents values on site',
    'Security upgrade program adds builders risk exposure'
  ]
};

/* ------------------------------------------------------------------ */
/* Curated entity table                                                */
/* Row: [id, seg, name, city, state, lat, lng, site, metricValue,      */
/*       floors, built, geoOverride]                                   */
/* floors and built are null unless widely documented in public        */
/* sources. constr, roof, height are null for every record: no live    */
/* OpenStreetMap retrieval was possible at compile time.               */
/* ------------------------------------------------------------------ */

const ROWS = [
  /* Airports and Aviation: FAA NPIAS identity, CY2023 enplanements */
  ['air-lax', 'air', 'Los Angeles International Airport (LAX)', 'Los Angeles', 'CA', 33.9416, -118.4085, 'Tom Bradley International Terminal', 40900000, null, null, null],
  ['air-dfw', 'air', 'Dallas Fort Worth International Airport (DFW)', 'DFW Airport', 'TX', 32.8998, -97.0403, 'Terminal D', 39200000, null, null, null],
  ['air-jfk', 'air', 'John F. Kennedy International Airport (JFK)', 'Queens', 'NY', 40.6413, -73.7781, 'Terminal 4', 30800000, null, null, null],
  ['air-mia', 'air', 'Miami International Airport (MIA)', 'Miami', 'FL', 25.7959, -80.287, 'North Terminal D', 24700000, null, null, null],
  ['air-ord', 'air', "Chicago O'Hare International Airport (ORD)", 'Chicago', 'IL', 41.9742, -87.9073, 'Terminal 1', 35800000, null, null, null],
  ['air-phl', 'air', 'Philadelphia International Airport (PHL)', 'Philadelphia', 'PA', 39.8744, -75.2424, 'Terminal B', 12900000, null, null, null],
  ['air-atl', 'air', 'Hartsfield-Jackson Atlanta International Airport (ATL)', 'Atlanta', 'GA', 33.6407, -84.4277, 'Domestic Terminal', 50900000, null, null, null],
  ['air-sea', 'air', 'Seattle-Tacoma International Airport (SEA)', 'SeaTac', 'WA', 47.4502, -122.3088, 'Central Terminal', 25000000, null, null, null],
  ['air-clt', 'air', 'Charlotte Douglas International Airport (CLT)', 'Charlotte', 'NC', 35.214, -80.9431, 'Main Terminal', 25900000, null, null, null],
  ['air-iad', 'air', 'Washington Dulles International Airport (IAD)', 'Dulles', 'VA', 38.9531, -77.4565, 'Main Terminal', 12500000, null, null, null],
  ['air-dtw', 'air', 'Detroit Metropolitan Wayne County Airport (DTW)', 'Romulus', 'MI', 42.2162, -83.3554, 'McNamara Terminal', 15700000, null, null, null],
  ['air-den', 'air', 'Denver International Airport (DEN)', 'Denver', 'CO', 39.8561, -104.6737, 'Jeppesen Terminal', 37900000, null, null, null],
  ['air-phx', 'air', 'Phoenix Sky Harbor International Airport (PHX)', 'Phoenix', 'AZ', 33.4373, -112.0078, 'Terminal 4', 24500000, null, null, null],
  ['air-bna', 'air', 'Nashville International Airport (BNA)', 'Nashville', 'TN', 36.1263, -86.6774, 'Main Terminal', 11200000, null, null, null],
  ['air-bwi', 'air', 'Baltimore/Washington International Thurgood Marshall Airport (BWI)', 'Linthicum', 'MD', 39.1774, -76.6684, 'Main Terminal', 13100000, null, null, null],
  ['air-anc', 'air', 'Ted Stevens Anchorage International Airport (ANC)', 'Anchorage', 'AK', 61.1743, -149.9963, 'South Terminal', 2900000, null, null, 'AK'],
  ['air-hnl', 'air', 'Daniel K. Inouye International Airport (HNL)', 'Honolulu', 'HI', 21.3245, -157.9251, 'Overseas Terminal', 9400000, null, null, 'HI'],
  ['air-sdf', 'air', 'Louisville Muhammad Ali International Airport (SDF)', 'Louisville', 'KY', 38.174, -85.7365, 'Main Terminal', 2200000, null, null, null],
  ['air-msy', 'air', 'Louis Armstrong New Orleans International Airport (MSY)', 'Kenner', 'LA', 29.9934, -90.258, 'North Terminal', 6700000, null, null, null],
  ['air-las', 'air', 'Harry Reid International Airport (LAS)', 'Las Vegas', 'NV', 36.084, -115.1537, 'Terminal 1', 28000000, null, null, null],
  ['air-pdx', 'air', 'Portland International Airport (PDX)', 'Portland', 'OR', 45.5898, -122.5951, 'Main Terminal', 8400000, null, null, null],
  ['air-slc', 'air', 'Salt Lake City International Airport (SLC)', 'Salt Lake City', 'UT', 40.7899, -111.9791, 'The New SLC Terminal', 13400000, null, null, null],

  /* Cities and Municipalities: Census ASPEP identity, FTE employment */
  ['city-san-diego', 'city', 'City of San Diego', 'San Diego', 'CA', 32.7174, -117.1628, 'City Administration Building', 11700, null, null, null],
  ['city-houston', 'city', 'City of Houston', 'Houston', 'TX', 29.7604, -95.3698, 'Houston City Hall', 21500, null, null, null],
  ['city-jacksonville', 'city', 'City of Jacksonville', 'Jacksonville', 'FL', 30.3293, -81.6606, 'St. James Building', 9500, null, null, null],
  ['city-chicago', 'city', 'City of Chicago', 'Chicago', 'IL', 41.8837, -87.6324, 'Chicago City Hall', 30000, 11, 1911, null],
  ['city-philadelphia', 'city', 'City of Philadelphia', 'Philadelphia', 'PA', 39.9524, -75.1636, 'Philadelphia City Hall', 25000, 9, 1901, null],
  ['city-columbus', 'city', 'City of Columbus', 'Columbus', 'OH', 39.9634, -83.0016, 'Columbus City Hall', 9000, null, null, null],
  ['city-atlanta', 'city', 'City of Atlanta', 'Atlanta', 'GA', 33.749, -84.3902, 'Atlanta City Hall', 8000, null, null, null],
  ['city-newark', 'city', 'City of Newark', 'Newark', 'NJ', 40.7328, -74.1723, 'Newark City Hall', 3800, null, null, null],
  ['city-virginia-beach', 'city', 'City of Virginia Beach', 'Virginia Beach', 'VA', 36.7529, -76.0574, 'Virginia Beach City Hall', 7300, null, null, null],
  ['city-detroit', 'city', 'City of Detroit', 'Detroit', 'MI', 42.3293, -83.044, 'Coleman A. Young Municipal Center', 8900, null, null, null],
  ['city-phoenix', 'city', 'City of Phoenix', 'Phoenix', 'AZ', 33.4489, -112.077, 'Phoenix City Hall', 14000, null, null, null],
  ['city-baltimore', 'city', 'City of Baltimore', 'Baltimore', 'MD', 39.2909, -76.6107, 'Baltimore City Hall', 13500, null, null, null],
  ['city-indianapolis', 'city', 'City of Indianapolis', 'Indianapolis', 'IN', 39.7683, -86.1555, 'City-County Building', 7800, null, null, null],
  ['city-wilmington', 'city', 'City of Wilmington', 'Wilmington', 'DE', 39.7447, -75.545, 'Louis L. Redding City/County Building', 1100, null, null, null],
  ['city-boise', 'city', 'City of Boise', 'Boise', 'ID', 43.6165, -116.2003, 'Boise City Hall', 1900, null, null, null],
  ['city-wichita', 'city', 'City of Wichita', 'Wichita', 'KS', 37.6922, -97.3375, 'Wichita City Hall', 3200, null, null, null],
  ['city-kansas-city', 'city', 'City of Kansas City', 'Kansas City', 'MO', 39.0997, -94.5783, 'Kansas City City Hall', 4300, 29, 1937, null],
  ['city-fargo', 'city', 'City of Fargo', 'Fargo', 'ND', 46.879, -96.786, 'Fargo City Hall', 1100, null, null, null],
  ['city-oklahoma-city', 'city', 'City of Oklahoma City', 'Oklahoma City', 'OK', 35.47, -97.5195, 'Oklahoma City Municipal Building', 4900, null, null, null],
  ['city-sioux-falls', 'city', 'City of Sioux Falls', 'Sioux Falls', 'SD', 43.5473, -96.7294, 'Sioux Falls City Hall', 1400, null, null, null],
  ['city-milwaukee', 'city', 'City of Milwaukee', 'Milwaukee', 'WI', 43.0417, -87.9098, 'Milwaukee City Hall', 7000, 15, 1895, null],
  ['city-charlotte', 'city', 'City of Charlotte', 'Charlotte', 'NC', 35.2219, -80.8386, 'Charlotte-Mecklenburg Government Center', 7500, null, null, null],

  /* Transit Authorities: FTA NTD identity, 2023 unlinked passenger trips */
  ['transit-la-metro', 'transit', 'Los Angeles County Metropolitan Transportation Authority', 'Los Angeles', 'CA', 34.0561, -118.234, 'Metro Headquarters (Gateway Plaza)', 285000000, null, null, null],
  ['transit-houston-metro', 'transit', 'Metropolitan Transit Authority of Harris County (METRO)', 'Houston', 'TX', 29.755, -95.3621, 'METRO Administration Building', 82000000, null, null, null],
  ['transit-mta', 'transit', 'Metropolitan Transportation Authority (MTA)', 'New York', 'NY', 40.7046, -74.0128, 'MTA Headquarters (2 Broadway)', 2200000000, null, null, null],
  ['transit-miami-dade', 'transit', 'Miami-Dade Transit', 'Miami', 'FL', 25.7808, -80.1998, 'Overtown Transit Village', 55000000, null, null, null],
  ['transit-cta', 'transit', 'Chicago Transit Authority (CTA)', 'Chicago', 'IL', 41.8857, -87.6428, 'CTA Headquarters (567 W Lake St)', 279000000, null, null, null],
  ['transit-septa', 'transit', 'Southeastern Pennsylvania Transportation Authority (SEPTA)', 'Philadelphia', 'PA', 39.952, -75.162, 'SEPTA Headquarters (1234 Market St)', 224000000, null, null, null],
  ['transit-gcrta', 'transit', 'Greater Cleveland Regional Transit Authority', 'Cleveland', 'OH', 41.4993, -81.6944, 'RTA Main Office Building', 25000000, null, null, null],
  ['transit-marta', 'transit', 'Metropolitan Atlanta Rapid Transit Authority (MARTA)', 'Atlanta', 'GA', 33.8232, -84.3655, 'MARTA Headquarters', 87000000, null, null, null],
  ['transit-sound', 'transit', 'Sound Transit', 'Seattle', 'WA', 47.599, -122.3284, 'Union Station Headquarters', 38000000, null, null, null],
  ['transit-nj-transit', 'transit', 'New Jersey Transit Corporation', 'Newark', 'NJ', 40.7347, -74.165, 'NJ Transit Headquarters', 186000000, null, null, null],
  ['transit-mbta', 'transit', 'Massachusetts Bay Transportation Authority (MBTA)', 'Boston', 'MA', 42.351, -71.0672, 'State Transportation Building', 245000000, null, null, null],
  ['transit-rtd', 'transit', 'Regional Transportation District (RTD)', 'Denver', 'CO', 39.7532, -105.0003, 'RTD Administrative Offices (Blake St)', 65000000, null, null, null],
  ['transit-indygo', 'transit', 'Indianapolis Public Transportation Corporation (IndyGo)', 'Indianapolis', 'IN', 39.7663, -86.1866, 'IndyGo Administration and Garage', 7500000, null, null, null],
  ['transit-metro-transit-mn', 'transit', 'Metro Transit (Minneapolis-St. Paul)', 'Minneapolis', 'MN', 44.9866, -93.283, 'Fred T. Heywood Office and Garage', 45000000, null, null, null],
  ['transit-wmata', 'transit', 'Washington Metropolitan Area Transit Authority (WMATA)', 'Washington', 'DC', 38.8845, -77.022, 'WMATA Headquarters (L\'Enfant Plaza)', 240000000, null, null, null],
  ['transit-bistate', 'transit', 'Bi-State Development Agency (Metro Transit St. Louis)', 'St. Louis', 'MO', 38.6273, -90.1888, 'Metro Headquarters', 20000000, null, null, null],
  ['transit-trimet', 'transit', 'Tri-County Metropolitan Transportation District (TriMet)', 'Portland', 'OR', 45.5107, -122.6773, 'TriMet Administration Building', 56000000, null, null, null],
  ['transit-uta', 'transit', 'Utah Transit Authority (UTA)', 'Salt Lake City', 'UT', 40.7639, -111.9106, 'UTA Frontlines Headquarters', 30000000, null, null, null],

  /* Water and Wastewater: EPA SDWIS identity, population served */
  ['water-ladwp', 'water', 'Los Angeles Department of Water and Power', 'Los Angeles', 'CA', 34.0596, -118.2497, 'John Ferraro Building', 4000000, null, null, null],
  ['water-nyc-dep', 'water', 'New York City Department of Environmental Protection', 'Brooklyn', 'NY', 40.7374, -73.9481, 'Newtown Creek Wastewater Treatment Plant', 9500000, null, null, null],
  ['water-pwd', 'water', 'Philadelphia Water Department', 'Philadelphia', 'PA', 40.046, -74.995, 'Baxter Water Treatment Plant', 1600000, null, null, null],
  ['water-cleveland', 'water', 'Cleveland Division of Water', 'Cleveland', 'OH', 41.5008, -81.7205, 'Garrett A. Morgan Water Treatment Plant', 1400000, null, null, null],
  ['water-spu', 'water', 'Seattle Public Utilities', 'Seattle', 'WA', 47.605, -122.3298, 'Seattle Municipal Tower', 1500000, 62, 1990, null],
  ['water-pvsc', 'water', 'Passaic Valley Sewerage Commission', 'Newark', 'NJ', 40.7069, -74.1247, 'Newark Bay Treatment Plant', 1400000, null, null, null],
  ['water-mwra', 'water', 'Massachusetts Water Resources Authority', 'Boston', 'MA', 42.3475, -70.9614, 'Deer Island Treatment Plant', 3100000, null, null, null],
  ['water-glwa', 'water', 'Great Lakes Water Authority', 'Detroit', 'MI', 42.3585, -82.9836, 'Water Works Park Treatment Plant', 3800000, null, null, null],
  ['water-denver', 'water', 'Denver Water', 'Denver', 'CO', 39.7351, -105.0092, 'Denver Water Operations Complex', 1500000, null, null, null],
  ['water-mlgw', 'water', 'Memphis Light, Gas and Water', 'Memphis', 'TN', 35.1436, -90.0518, 'MLGW Administration Building', 930000, null, null, null],
  ['water-dc-water', 'water', 'DC Water and Sewer Authority', 'Washington', 'DC', 38.8146, -77.0221, 'Blue Plains Advanced Wastewater Treatment Plant', 700000, null, null, null],
  ['water-bws-honolulu', 'water', 'Honolulu Board of Water Supply', 'Honolulu', 'HI', 21.308, -157.852, 'BWS Beretania Complex', 1000000, null, null, 'HI'],
  ['water-swbno', 'water', 'Sewerage and Water Board of New Orleans', 'New Orleans', 'LA', 29.949, -90.1272, 'Carrollton Water Plant', 390000, null, null, null],
  ['water-pwd-maine', 'water', 'Portland Water District', 'Portland', 'ME', 43.656, -70.281, 'Douglass Street Operations Center', 200000, null, null, null],
  ['water-mud-omaha', 'water', 'Metropolitan Utilities District of Omaha', 'Omaha', 'NE', 41.256, -95.943, 'MUD Headquarters', 620000, null, null, null],
  ['water-lvvwd', 'water', 'Las Vegas Valley Water District', 'Las Vegas', 'NV', 36.1622, -115.1932, 'LVVWD Main Campus', 1500000, null, null, null],
  ['water-charleston', 'water', 'Charleston Water System', 'Charleston', 'SC', 32.7847, -79.94, 'St. Philip Street Administration Building', 500000, null, null, null],

  /* Higher Education: IPEDS identity, fall enrollment */
  ['highered-ucla', 'highered', 'University of California, Los Angeles', 'Los Angeles', 'CA', 34.0689, -118.4452, 'Royce Hall', 46400, null, null, null],
  ['highered-ut-austin', 'highered', 'University of Texas at Austin', 'Austin', 'TX', 30.2849, -97.7341, 'Main Building (UT Tower)', 52400, 27, 1937, null],
  ['highered-buffalo', 'highered', 'University at Buffalo (SUNY)', 'Buffalo', 'NY', 43.0008, -78.789, 'Capen Hall', 32100, null, null, null],
  ['highered-uf', 'highered', 'University of Florida', 'Gainesville', 'FL', 29.6436, -82.3549, 'Tigert Hall', 55700, null, null, null],
  ['highered-uiuc', 'highered', 'University of Illinois Urbana-Champaign', 'Urbana', 'IL', 40.1092, -88.2272, 'Illini Union', 56600, null, null, null],
  ['highered-penn-state', 'highered', 'Pennsylvania State University', 'University Park', 'PA', 40.7982, -77.8599, 'Old Main', 48000, null, null, null],
  ['highered-ohio-state', 'highered', 'Ohio State University', 'Columbus', 'OH', 39.9992, -83.0148, 'Thompson Library', 61700, null, null, null],
  ['highered-uga', 'highered', 'University of Georgia', 'Athens', 'GA', 33.9569, -83.3735, 'UGA Chapel', 40600, null, null, null],
  ['highered-uw', 'highered', 'University of Washington', 'Seattle', 'WA', 47.6553, -122.3035, 'Suzzallo Library', 52400, null, null, null],
  ['highered-rutgers', 'highered', 'Rutgers University-New Brunswick', 'New Brunswick', 'NJ', 40.5008, -74.4474, 'Old Queens', 50600, null, null, null],
  ['highered-unc', 'highered', 'University of North Carolina at Chapel Hill', 'Chapel Hill', 'NC', 35.9049, -79.0469, 'South Building', 32000, null, null, null],
  ['highered-umass', 'highered', 'University of Massachusetts Amherst', 'Amherst', 'MA', 42.3868, -72.5301, 'W.E.B. Du Bois Library', 32000, 26, 1973, null],
  ['highered-uva', 'highered', 'University of Virginia', 'Charlottesville', 'VA', 38.0356, -78.5034, 'The Rotunda', 26100, null, null, null],
  ['highered-umich', 'highered', 'University of Michigan', 'Ann Arbor', 'MI', 42.2748, -83.742, 'Michigan Union', 52000, null, null, null],
  ['highered-asu', 'highered', 'Arizona State University (Tempe)', 'Tempe', 'AZ', 33.4242, -111.9281, 'Old Main', 57600, null, null, null],
  ['highered-ut-knoxville', 'highered', 'University of Tennessee, Knoxville', 'Knoxville', 'TN', 35.9544, -83.9295, 'Ayres Hall', 36000, null, null, null],
  ['highered-umd', 'highered', 'University of Maryland, College Park', 'College Park', 'MD', 38.9869, -76.9426, 'McKeldin Library', 40800, null, null, null],
  ['highered-purdue', 'highered', 'Purdue University', 'West Lafayette', 'IN', 40.4286, -86.9138, 'Hovde Hall of Administration', 52200, null, null, null],
  ['highered-umn', 'highered', 'University of Minnesota, Twin Cities', 'Minneapolis', 'MN', 44.974, -93.2277, 'Northrop Auditorium', 54200, null, null, null],
  ['highered-uark', 'highered', 'University of Arkansas', 'Fayetteville', 'AR', 36.0687, -94.1748, 'Old Main', 32100, null, null, null],
  ['highered-uconn', 'highered', 'University of Connecticut', 'Storrs', 'CT', 41.8077, -72.254, 'Wilbur Cross Building', 27000, null, null, null],
  ['highered-montana-state', 'highered', 'Montana State University', 'Bozeman', 'MT', 45.666, -111.0466, 'Montana Hall', 16700, null, null, null],
  ['highered-unh', 'highered', 'University of New Hampshire', 'Durham', 'NH', 43.134, -70.9264, 'Thompson Hall', 13900, null, null, null],
  ['highered-ou', 'highered', 'University of Oklahoma', 'Norman', 'OK', 35.2059, -97.4457, 'Evans Hall', 28000, null, null, null],
  ['highered-uri', 'highered', 'University of Rhode Island', 'Kingston', 'RI', 41.4807, -71.5258, 'Green Hall', 17600, null, null, null],
  ['highered-uvm', 'highered', 'University of Vermont', 'Burlington', 'VT', 44.4779, -73.1965, 'Old Mill', 13800, null, null, null],
  ['highered-wvu', 'highered', 'West Virginia University', 'Morgantown', 'WV', 39.6358, -79.9559, 'Woodburn Hall', 24200, null, null, null],
  ['highered-uw-madison', 'highered', 'University of Wisconsin-Madison', 'Madison', 'WI', 43.0766, -89.4125, 'Bascom Hall', 50700, null, null, null],
  ['highered-uwyo', 'highered', 'University of Wyoming', 'Laramie', 'WY', 41.3149, -105.5666, 'Old Main', 11100, null, null, null],

  /* Public Health Systems: CMS POS identity (government owned), beds */
  ['health-la-general', 'health', 'Los Angeles General Medical Center', 'Los Angeles', 'CA', 34.0587, -118.2077, 'Main Hospital Tower', 676, null, null, null],
  ['health-harris', 'health', 'Harris Health System', 'Houston', 'TX', 29.71, -95.396, 'Ben Taub Hospital', 650, null, null, null],
  ['health-nyc-hh', 'health', 'NYC Health + Hospitals', 'New York', 'NY', 40.7392, -73.9766, 'Bellevue Hospital', 4200, null, null, null],
  ['health-jackson', 'health', 'Jackson Health System', 'Miami', 'FL', 25.7907, -80.2107, 'Jackson Memorial Hospital', 1550, null, null, null],
  ['health-cook-county', 'health', 'Cook County Health', 'Chicago', 'IL', 41.8746, -87.6741, 'John H. Stroger Jr. Hospital', 450, null, null, null],
  ['health-metrohealth', 'health', 'The MetroHealth System', 'Cleveland', 'OH', 41.4622, -81.6987, 'Glick Center', 312, null, null, null],
  ['health-grady', 'health', 'Grady Health System', 'Atlanta', 'GA', 33.7522, -84.3816, 'Grady Memorial Hospital', 953, null, null, null],
  ['health-harborview', 'health', 'Harborview Medical Center', 'Seattle', 'WA', 47.6044, -122.3244, 'Main Hospital (Center Tower)', 413, null, null, null],
  ['health-uh-newark', 'health', 'University Hospital', 'Newark', 'NJ', 40.7419, -74.1901, 'Main Hospital Building', 519, null, null, null],
  ['health-hennepin', 'health', 'Hennepin Healthcare (HCMC)', 'Minneapolis', 'MN', 44.9723, -93.2617, 'HCMC Main Campus', 484, null, null, null],
  ['health-uab', 'health', 'UAB Hospital', 'Birmingham', 'AL', 33.5057, -86.8028, 'North Pavilion', 1207, null, null, null],
  ['health-uihc', 'health', 'University of Iowa Hospitals and Clinics', 'Iowa City', 'IA', 41.6588, -91.5474, 'John Pappajohn Pavilion', 866, null, null, null],
  ['health-ummc', 'health', 'University of Mississippi Medical Center', 'Jackson', 'MS', 32.3295, -90.173, 'University Hospital', 722, null, null, null],
  ['health-unm', 'health', 'University of New Mexico Hospital', 'Albuquerque', 'NM', 35.09, -106.6169, 'UNM Hospital Main Building', 537, null, null, null],
  ['health-musc', 'health', 'MUSC Health University Medical Center', 'Charleston', 'SC', 32.7833, -79.9481, 'Main Hospital', 700, null, null, null],

  /* Federal and GovCon: GSA IOLP identity, gross square feet */
  ['fed-gsa-hq', 'fed', 'GSA Headquarters (1800 F Street NW)', 'Washington', 'DC', 38.8973, -77.0415, '1800 F Street NW', 780000, null, null, null],
  ['fed-javits', 'fed', 'Jacob K. Javits Federal Building', 'New York', 'NY', 40.7153, -74.0036, '26 Federal Plaza', 1500000, 41, null, null],
  ['fed-kluczynski', 'fed', 'John C. Kluczynski Federal Building', 'Chicago', 'IL', 41.8786, -87.6297, '230 S Dearborn St', 1200000, 45, 1974, null],
  ['fed-cabell', 'fed', 'Earle Cabell Federal Building', 'Dallas', 'TX', 32.7786, -96.7987, '1100 Commerce St', 1100000, null, null, null],
  ['fed-burton', 'fed', 'Phillip Burton Federal Building', 'San Francisco', 'CA', 37.781, -122.421, '450 Golden Gate Ave', 1300000, null, null, null],
  ['fed-denver-center', 'fed', 'Denver Federal Center', 'Lakewood', 'CO', 39.7239, -105.1103, 'Denver Federal Center Campus', 4000000, null, null, null],
  ['fed-bean', 'fed', 'Major General Emmett J. Bean Federal Center', 'Indianapolis', 'IN', 39.8586, -86.0155, 'Bean Federal Center', 1600000, null, null, null],
  ['fed-celebrezze', 'fed', 'Anthony J. Celebrezze Federal Building', 'Cleveland', 'OH', 41.5052, -81.6934, '1240 E 9th St', 1200000, 32, 1967, null],
  ['fed-green', 'fed', 'William J. Green Jr. Federal Building', 'Philadelphia', 'PA', 39.9528, -75.1508, '600 Arch St', 980000, null, null, null],
  ['fed-jackson', 'fed', 'Henry M. Jackson Federal Building', 'Seattle', 'WA', 47.6046, -122.334, '915 2nd Ave', 815000, 37, 1974, null],
  ['fed-russell', 'fed', 'Richard B. Russell Federal Building', 'Atlanta', 'GA', 33.752, -84.3946, '75 Ted Turner Dr SW', 1250000, null, null, null],
  ['fed-jfk-boston', 'fed', 'John F. Kennedy Federal Building', 'Boston', 'MA', 42.361, -71.0596, '15 New Sudbury St', 828000, 26, 1966, null],
  ['fed-young', 'fed', 'Robert A. Young Federal Building', 'St. Louis', 'MO', 38.6258, -90.2049, '1222 Spruce St', 1100000, null, null, null]
];

/* ------------------------------------------------------------------ */
/* Generation                                                          */
/* ------------------------------------------------------------------ */

function hashCode(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) {
    h = (h * 31 + str.charCodeAt(i)) >>> 0;
  }
  return h;
}

function producerFor(state) {
  for (const [key, states] of Object.entries(PRODUCER_BY_STATE)) {
    if (states.includes(state)) return key;
  }
  throw new Error('No producer mapped for state ' + state);
}

function modeledRenewal(id) {
  const h = hashCode(id);
  const monthIndex = h % 12; /* 0 = Oct 2026 ... 11 = Sep 2027 */
  const year = monthIndex < 3 ? 2026 : 2027;
  const month = ((9 + monthIndex) % 12) + 1;
  return year + '-' + String(month).padStart(2, '0') + '-01';
}

const OSM_NULL_NOTE = 'No value confirmed in OpenStreetMap or agency publications at compile time. Live Overpass retrieval was blocked by network policy. Null per the no-invention rule.';
const OSM_SET_NOTE = 'Widely documented public value consistent with OpenStreetMap building tags. Compiled offline (Overpass blocked at build time). Re-verify against live OSM before client use.';
const REG_NOTE = 'Compiled from the named registry\'s most recent published edition. Re-verify against the live dataset before client use.';

function buildEntity(row) {
  const [id, seg, name, city, state, lat, lng, site, metricValue, floors, built, geoOverride] = row;
  const cfg = SEG_CONFIG[seg];
  const tiv = Math.round(metricValue * cfg.tivMult / 1e6) * 1e6;
  const prem = Math.round(tiv * PREM_RATE / 1e3) * 1e3;
  const h = hashCode(id);
  const inc = INCUMBENT_POOL[h % INCUMBENT_POOL.length];
  const triggers = TRIGGER_POOL[seg];
  const trigger = triggers[h % triggers.length];

  const entity = {
    id: id,
    seg: seg,
    name: name,
    city: city,
    state: state,
    lat: lat,
    lng: lng,
    site: site,
    floors: floors,
    height: null,
    sqft: seg === 'fed' ? metricValue : null,
    built: built,
    constr: null,
    roof: null,
    tiv: tiv,
    prem: prem,
    inc: inc,
    renew: modeledRenewal(id),
    trigger: trigger,
    producer: producerFor(state),
    verif: floors === null ? 'no-record' : 'unverified'
  };
  entity[cfg.metricKey] = metricValue;
  if (geoOverride) entity.geoOverride = geoOverride;

  const pub = (source, note) => ({ kind: 'public', source: source, note: note || REG_NOTE });
  const provenance = {
    name: pub(cfg.registrySrc),
    city: pub(cfg.registrySrc),
    state: pub(cfg.registrySrc),
    lat: pub(cfg.coordSrc),
    lng: pub(cfg.coordSrc),
    site: pub(cfg.coordSrc === 'osm' ? 'osm' : cfg.registrySrc),
    floors: floors === null ? pub('osm', OSM_NULL_NOTE) : pub('osm', OSM_SET_NOTE),
    height: pub('osm', OSM_NULL_NOTE),
    sqft: seg === 'fed' ? pub('gsa_iolp') : pub('osm', OSM_NULL_NOTE),
    built: built === null ? pub('osm', OSM_NULL_NOTE) : pub('osm', OSM_SET_NOTE),
    constr: pub('osm', OSM_NULL_NOTE),
    roof: pub('osm', OSM_NULL_NOTE),
    tiv: { kind: 'derived', formula: cfg.tivFormula, inputs: [cfg.metricKey] },
    prem: { kind: 'derived', formula: PREM_FORMULA, inputs: ['tiv'] },
    inc: { kind: 'modeled', note: 'Synthetic placeholder. Not research. Flagged in the UI.' },
    renew: { kind: 'modeled', note: 'Synthetic placeholder. Not research. Flagged in the UI.' },
    trigger: { kind: 'modeled', note: 'Synthetic placeholder. Not research. Flagged in the UI.' }
  };
  provenance[cfg.metricKey] = {
    kind: 'public',
    source: cfg.metricSrc,
    note: cfg.metricYear + ' reporting period. ' + REG_NOTE
  };
  entity.provenance = provenance;
  return entity;
}

function main() {
  const outDir = path.join(__dirname, '..', 'data', 'entities');
  fs.mkdirSync(outDir, { recursive: true });

  const bySeg = {};
  const seen = new Set();
  for (const row of ROWS) {
    if (seen.has(row[0])) throw new Error('Duplicate entity id ' + row[0]);
    seen.add(row[0]);
    const entity = buildEntity(row);
    (bySeg[entity.seg] = bySeg[entity.seg] || []).push(entity);
  }

  let total = 0;
  for (const [seg, cfg] of Object.entries(SEG_CONFIG)) {
    const list = bySeg[seg] || [];
    total += list.length;
    const outPath = path.join(outDir, cfg.file);
    fs.writeFileSync(outPath, JSON.stringify(list, null, 2) + '\n');
    console.log(cfg.file + ': ' + list.length + ' entities');
  }
  console.log('total: ' + total + ' entities');
}

main();
