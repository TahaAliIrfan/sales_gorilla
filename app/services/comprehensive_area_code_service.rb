class ComprehensiveAreaCodeService
  # Area code to location mapping for all major countries

  def self.get_location_data(area_code, country_code)
    return nil unless area_code.present? && country_code.present?

    case country_code.upcase
    when "US", "CA"
      us_canada_area_codes(area_code)
    when "GB", "UK"
      uk_area_codes(area_code)
    when "AU"
      australia_area_codes(area_code)
    when "DE"
      germany_area_codes(area_code)
    when "FR"
      france_area_codes(area_code)
    when "IT"
      italy_area_codes(area_code)
    when "ES"
      spain_area_codes(area_code)
    when "NL"
      netherlands_area_codes(area_code)
    when "BE"
      belgium_area_codes(area_code)
    when "CH"
      switzerland_area_codes(area_code)
    when "AT"
      austria_area_codes(area_code)
    when "SE"
      sweden_area_codes(area_code)
    when "NO"
      norway_area_codes(area_code)
    when "DK"
      denmark_area_codes(area_code)
    when "FI"
      finland_area_codes(area_code)
    when "IE"
      ireland_area_codes(area_code)
    when "PT"
      portugal_area_codes(area_code)
    # Middle East countries
    when "AE"
      uae_area_codes(area_code)
    when "SA"
      saudi_arabia_area_codes(area_code)
    when "QA"
      qatar_area_codes(area_code)
    when "KW"
      kuwait_area_codes(area_code)
    when "BH"
      bahrain_area_codes(area_code)
    when "OM"
      oman_area_codes(area_code)
    when "JO"
      jordan_area_codes(area_code)
    when "LB"
      lebanon_area_codes(area_code)
    when "IL"
      israel_area_codes(area_code)
    when "TR"
      turkey_area_codes(area_code)
    when "IR"
      iran_area_codes(area_code)
    when "IQ"
      iraq_area_codes(area_code)
    when "EG"
      egypt_area_codes(area_code)
    # Asian countries
    when "JP"
      japan_area_codes(area_code)
    when "KR"
      south_korea_area_codes(area_code)
    when "CN"
      china_area_codes(area_code)
    when "IN"
      india_area_codes(area_code)
    when "PK"
      pakistan_area_codes(area_code)
    when "BD"
      bangladesh_area_codes(area_code)
    when "SG"
      singapore_area_codes(area_code)
    when "MY"
      malaysia_area_codes(area_code)
    when "TH"
      thailand_area_codes(area_code)
    when "VN"
      vietnam_area_codes(area_code)
    when "PH"
      philippines_area_codes(area_code)
    when "ID"
      indonesia_area_codes(area_code)
    # Other major countries
    when "BR"
      brazil_area_codes(area_code)
    when "MX"
      mexico_area_codes(area_code)
    when "AR"
      argentina_area_codes(area_code)
    when "RU"
      russia_area_codes(area_code)
    when "ZA"
      south_africa_area_codes(area_code)
    when "NZ"
      new_zealand_area_codes(area_code)
    else
      nil
    end
  end

  private

  # United States and Canada (NANP)
  def self.us_canada_area_codes(area_code)
    area_code_map = {
      # Major US Cities
      "212" => { state: "NY", city: "New York", country: "US", region: "Manhattan", coordinates: { lat: 40.7589, lng: -73.9851 } },
      "213" => { state: "CA", city: "Los Angeles", country: "US", region: "Downtown LA", coordinates: { lat: 34.0522, lng: -118.2437 } },
      "214" => { state: "TX", city: "Dallas", country: "US", region: "Dallas", coordinates: { lat: 32.7767, lng: -96.7970 } },
      "215" => { state: "PA", city: "Philadelphia", country: "US", region: "Philadelphia", coordinates: { lat: 39.9526, lng: -75.1652 } },
      "216" => { state: "OH", city: "Cleveland", country: "US", region: "Cleveland", coordinates: { lat: 41.4993, lng: -81.6944 } },
      "217" => { state: "IL", city: "Springfield", country: "US", region: "Central Illinois", coordinates: { lat: 39.7817, lng: -89.6501 } },
      "281" => { state: "TX", city: "Houston", country: "US", region: "Houston Metro", coordinates: { lat: 29.7604, lng: -95.3698 } },
      "301" => { state: "MD", city: "Bethesda", country: "US", region: "Maryland", coordinates: { lat: 38.9047, lng: -77.0947 } },
      "302" => { state: "DE", city: "Wilmington", country: "US", region: "Delaware", coordinates: { lat: 39.7391, lng: -75.5398 } },
      "303" => { state: "CO", city: "Denver", country: "US", region: "Denver Metro", coordinates: { lat: 39.7392, lng: -104.9903 } },
      "304" => { state: "WV", city: "Charleston", country: "US", region: "West Virginia", coordinates: { lat: 38.3498, lng: -81.6326 } },
      "305" => { state: "FL", city: "Miami", country: "US", region: "Miami-Dade", coordinates: { lat: 25.7617, lng: -80.1918 } },
      "310" => { state: "CA", city: "Beverly Hills", country: "US", region: "West LA", coordinates: { lat: 34.0736, lng: -118.4004 } },
      "312" => { state: "IL", city: "Chicago", country: "US", region: "Downtown Chicago", coordinates: { lat: 41.8781, lng: -87.6298 } },
      "313" => { state: "MI", city: "Detroit", country: "US", region: "Detroit", coordinates: { lat: 42.3314, lng: -83.0458 } },
      "314" => { state: "MO", city: "St. Louis", country: "US", region: "St. Louis", coordinates: { lat: 38.6270, lng: -90.1994 } },
      "315" => { state: "NY", city: "Syracuse", country: "US", region: "Central NY", coordinates: { lat: 43.0481, lng: -76.1474 } },
      "316" => { state: "KS", city: "Wichita", country: "US", region: "Kansas", coordinates: { lat: 37.6872, lng: -97.3301 } },
      "317" => { state: "IN", city: "Indianapolis", country: "US", region: "Indianapolis", coordinates: { lat: 39.7684, lng: -86.1581 } },
      "318" => { state: "LA", city: "Shreveport", country: "US", region: "Northern Louisiana", coordinates: { lat: 32.5252, lng: -93.7502 } },
      "319" => { state: "IA", city: "Cedar Rapids", country: "US", region: "Eastern Iowa", coordinates: { lat: 41.9778, lng: -91.6656 } },
      "404" => { state: "GA", city: "Atlanta", country: "US", region: "Atlanta Metro", coordinates: { lat: 33.7490, lng: -84.3880 } },
      "405" => { state: "OK", city: "Oklahoma City", country: "US", region: "Oklahoma", coordinates: { lat: 35.4676, lng: -97.5164 } },
      "407" => { state: "FL", city: "Orlando", country: "US", region: "Central Florida", coordinates: { lat: 28.5383, lng: -81.3792 } },
      "408" => { state: "CA", city: "San Jose", country: "US", region: "Silicon Valley", coordinates: { lat: 37.3382, lng: -121.8863 } },
      "409" => { state: "TX", city: "Beaumont", country: "US", region: "Southeast Texas", coordinates: { lat: 30.0860, lng: -94.1018 } },
      "410" => { state: "MD", city: "Baltimore", country: "US", region: "Maryland", coordinates: { lat: 39.2904, lng: -76.6122 } },
      "412" => { state: "PA", city: "Pittsburgh", country: "US", region: "Pittsburgh", coordinates: { lat: 40.4406, lng: -79.9959 } },
      "413" => { state: "MA", city: "Springfield", country: "US", region: "Western Massachusetts", coordinates: { lat: 42.1015, lng: -72.5898 } },
      "414" => { state: "WI", city: "Milwaukee", country: "US", region: "Milwaukee", coordinates: { lat: 43.0389, lng: -87.9065 } },
      "415" => { state: "CA", city: "San Francisco", country: "US", region: "San Francisco", coordinates: { lat: 37.7749, lng: -122.4194 } },
      "416" => { state: "ON", city: "Toronto", country: "CA", region: "Toronto", coordinates: { lat: 43.6532, lng: -79.3832 } },
      "417" => { state: "MO", city: "Springfield", country: "US", region: "Southwest Missouri", coordinates: { lat: 37.2089, lng: -93.2923 } },
      "418" => { state: "QC", city: "Quebec City", country: "CA", region: "Quebec", coordinates: { lat: 46.8139, lng: -71.2080 } },
      "419" => { state: "OH", city: "Toledo", country: "US", region: "Northwest Ohio", coordinates: { lat: 41.6528, lng: -83.5379 } },
      "501" => { state: "AR", city: "Little Rock", country: "US", region: "Arkansas", coordinates: { lat: 34.7465, lng: -92.2896 } },
      "502" => { state: "KY", city: "Louisville", country: "US", region: "Kentucky", coordinates: { lat: 38.2527, lng: -85.7585 } },
      "503" => { state: "OR", city: "Portland", country: "US", region: "Oregon", coordinates: { lat: 45.5152, lng: -122.6784 } },
      "504" => { state: "LA", city: "New Orleans", country: "US", region: "Louisiana", coordinates: { lat: 29.9511, lng: -90.0715 } },
      "505" => { state: "NM", city: "Albuquerque", country: "US", region: "New Mexico", coordinates: { lat: 35.0844, lng: -106.6504 } },
      "506" => { state: "NB", city: "Moncton", country: "CA", region: "New Brunswick", coordinates: { lat: 46.0878, lng: -64.7782 } },
      "507" => { state: "MN", city: "Rochester", country: "US", region: "Southern Minnesota", coordinates: { lat: 44.0121, lng: -92.4802 } },
      "508" => { state: "MA", city: "Worcester", country: "US", region: "Central Massachusetts", coordinates: { lat: 42.2626, lng: -71.8023 } },
      "509" => { state: "WA", city: "Spokane", country: "US", region: "Eastern Washington", coordinates: { lat: 47.6587, lng: -117.4260 } },
      "510" => { state: "CA", city: "Oakland", country: "US", region: "East Bay", coordinates: { lat: 37.8044, lng: -122.2712 } },
      "512" => { state: "TX", city: "Austin", country: "US", region: "Austin", coordinates: { lat: 30.2672, lng: -97.7431 } },
      "513" => { state: "OH", city: "Cincinnati", country: "US", region: "Cincinnati", coordinates: { lat: 39.1031, lng: -84.5120 } },
      "514" => { state: "QC", city: "Montreal", country: "CA", region: "Montreal", coordinates: { lat: 45.5017, lng: -73.5673 } },
      "515" => { state: "IA", city: "Des Moines", country: "US", region: "Iowa", coordinates: { lat: 41.5868, lng: -93.6250 } },
      "516" => { state: "NY", city: "Hempstead", country: "US", region: "Long Island", coordinates: { lat: 40.7062, lng: -73.6187 } },
      "517" => { state: "MI", city: "Lansing", country: "US", region: "Central Michigan", coordinates: { lat: 42.3314, lng: -84.5467 } },
      "518" => { state: "NY", city: "Albany", country: "US", region: "Capital District", coordinates: { lat: 42.6526, lng: -73.7562 } },
      "519" => { state: "ON", city: "London", country: "CA", region: "Southwestern Ontario", coordinates: { lat: 42.9849, lng: -81.2453 } },
      "520" => { state: "AZ", city: "Tucson", country: "US", region: "Arizona", coordinates: { lat: 32.2217, lng: -110.9265 } },
      "601" => { state: "MS", city: "Jackson", country: "US", region: "Mississippi", coordinates: { lat: 32.2988, lng: -90.1848 } },
      "602" => { state: "AZ", city: "Phoenix", country: "US", region: "Phoenix Metro", coordinates: { lat: 33.4484, lng: -112.0740 } },
      "603" => { state: "NH", city: "Manchester", country: "US", region: "New Hampshire", coordinates: { lat: 42.9956, lng: -71.4548 } },
      "604" => { state: "BC", city: "Vancouver", country: "CA", region: "Vancouver", coordinates: { lat: 49.2827, lng: -123.1207 } },
      "605" => { state: "SD", city: "Sioux Falls", country: "US", region: "South Dakota", coordinates: { lat: 43.5460, lng: -96.7313 } },
      "606" => { state: "KY", city: "Ashland", country: "US", region: "Eastern Kentucky", coordinates: { lat: 38.4784, lng: -82.6440 } },
      "607" => { state: "NY", city: "Binghamton", country: "US", region: "Southern Tier", coordinates: { lat: 42.0987, lng: -75.9180 } },
      "608" => { state: "WI", city: "Madison", country: "US", region: "Southern Wisconsin", coordinates: { lat: 43.0731, lng: -89.4012 } },
      "609" => { state: "NJ", city: "Trenton", country: "US", region: "Central New Jersey", coordinates: { lat: 40.2206, lng: -74.7565 } },
      "610" => { state: "PA", city: "Allentown", country: "US", region: "Eastern Pennsylvania", coordinates: { lat: 40.6084, lng: -75.4902 } },
      "612" => { state: "MN", city: "Minneapolis", country: "US", region: "Twin Cities", coordinates: { lat: 44.9778, lng: -93.2650 } },
      "613" => { state: "ON", city: "Ottawa", country: "CA", region: "Ottawa", coordinates: { lat: 45.4215, lng: -75.6972 } },
      "614" => { state: "OH", city: "Columbus", country: "US", region: "Columbus", coordinates: { lat: 39.9612, lng: -82.9988 } },
      "615" => { state: "TN", city: "Nashville", country: "US", region: "Nashville", coordinates: { lat: 36.1627, lng: -86.7816 } },
      "616" => { state: "MI", city: "Grand Rapids", country: "US", region: "West Michigan", coordinates: { lat: 42.9634, lng: -85.6681 } },
      "617" => { state: "MA", city: "Boston", country: "US", region: "Boston", coordinates: { lat: 42.3601, lng: -71.0589 } },
      "618" => { state: "IL", city: "Belleville", country: "US", region: "Southern Illinois", coordinates: { lat: 38.5201, lng: -89.9840 } },
      "619" => { state: "CA", city: "San Diego", country: "US", region: "San Diego", coordinates: { lat: 32.7157, lng: -117.1611 } },
      "620" => { state: "KS", city: "Hutchinson", country: "US", region: "South Central Kansas", coordinates: { lat: 38.0608, lng: -97.9297 } },
      "701" => { state: "ND", city: "Fargo", country: "US", region: "North Dakota", coordinates: { lat: 46.8772, lng: -96.7898 } },
      "702" => { state: "NV", city: "Las Vegas", country: "US", region: "Las Vegas", coordinates: { lat: 36.1699, lng: -115.1398 } },
      "703" => { state: "VA", city: "Arlington", country: "US", region: "Northern Virginia", coordinates: { lat: 38.8816, lng: -77.0910 } },
      "704" => { state: "NC", city: "Charlotte", country: "US", region: "Charlotte Metro", coordinates: { lat: 35.2271, lng: -80.8431 } },
      "705" => { state: "ON", city: "Barrie", country: "CA", region: "Central Ontario", coordinates: { lat: 44.3894, lng: -79.6903 } },
      "706" => { state: "GA", city: "Augusta", country: "US", region: "North Georgia", coordinates: { lat: 33.4735, lng: -82.0105 } },
      "707" => { state: "CA", city: "Santa Rosa", country: "US", region: "North Bay", coordinates: { lat: 38.4404, lng: -122.7144 } },
      "708" => { state: "IL", city: "Chicago Heights", country: "US", region: "South Chicago Suburbs", coordinates: { lat: 41.5061, lng: -87.6356 } },
      "709" => { state: "NL", city: "St. Johns", country: "CA", region: "Newfoundland", coordinates: { lat: 47.5615, lng: -52.7126 } },
      "710" => { state: "US", city: "Government", country: "US", region: "Government Use", coordinates: { lat: 38.9072, lng: -77.0369 } },
      "712" => { state: "IA", city: "Sioux City", country: "US", region: "Western Iowa", coordinates: { lat: 42.4999, lng: -96.4003 } },
      "713" => { state: "TX", city: "Houston", country: "US", region: "Houston", coordinates: { lat: 29.7604, lng: -95.3698 } },
      "714" => { state: "CA", city: "Anaheim", country: "US", region: "Orange County", coordinates: { lat: 33.8366, lng: -117.9143 } },
      "715" => { state: "WI", city: "Eau Claire", country: "US", region: "North Central Wisconsin", coordinates: { lat: 44.8113, lng: -91.4985 } },
      "716" => { state: "NY", city: "Buffalo", country: "US", region: "Western New York", coordinates: { lat: 42.8864, lng: -78.8784 } },
      "717" => { state: "PA", city: "Harrisburg", country: "US", region: "South Central Pennsylvania", coordinates: { lat: 40.2732, lng: -76.8867 } },
      "718" => { state: "NY", city: "Brooklyn", country: "US", region: "NYC Boroughs", coordinates: { lat: 40.6782, lng: -73.9442 } },
      "719" => { state: "CO", city: "Colorado Springs", country: "US", region: "South Central Colorado", coordinates: { lat: 38.8339, lng: -104.8214 } },
      "720" => { state: "CO", city: "Denver", country: "US", region: "Denver Metro", coordinates: { lat: 39.7392, lng: -104.9903 } },
      "801" => { state: "UT", city: "Salt Lake City", country: "US", region: "Utah", coordinates: { lat: 40.7608, lng: -111.8910 } },
      "802" => { state: "VT", city: "Burlington", country: "US", region: "Vermont", coordinates: { lat: 44.4759, lng: -73.2121 } },
      "803" => { state: "SC", city: "Columbia", country: "US", region: "South Carolina", coordinates: { lat: 34.0007, lng: -81.0348 } },
      "804" => { state: "VA", city: "Richmond", country: "US", region: "Central Virginia", coordinates: { lat: 37.5407, lng: -77.4360 } },
      "805" => { state: "CA", city: "Santa Barbara", country: "US", region: "Central Coast", coordinates: { lat: 34.4208, lng: -119.6982 } },
      "806" => { state: "TX", city: "Lubbock", country: "US", region: "West Texas", coordinates: { lat: 33.5779, lng: -101.8552 } },
      "807" => { state: "ON", city: "Thunder Bay", country: "CA", region: "Northwestern Ontario", coordinates: { lat: 48.3809, lng: -89.2477 } },
      "808" => { state: "HI", city: "Honolulu", country: "US", region: "Hawaii", coordinates: { lat: 21.3099, lng: -157.8581 } },
      "809" => { state: "DO", city: "Santo Domingo", country: "DO", region: "Dominican Republic", coordinates: { lat: 18.4861, lng: -69.9312 } },
      "810" => { state: "MI", city: "Flint", country: "US", region: "East Central Michigan", coordinates: { lat: 43.0125, lng: -83.6875 } },
      "812" => { state: "IN", city: "Evansville", country: "US", region: "Southern Indiana", coordinates: { lat: 37.9716, lng: -87.5710 } },
      "813" => { state: "FL", city: "Tampa", country: "US", region: "Tampa Bay", coordinates: { lat: 27.9506, lng: -82.4572 } },
      "814" => { state: "PA", city: "Erie", country: "US", region: "Northwestern Pennsylvania", coordinates: { lat: 42.1292, lng: -80.0851 } },
      "815" => { state: "IL", city: "Rockford", country: "US", region: "Northern Illinois", coordinates: { lat: 42.2711, lng: -89.0940 } },
      "816" => { state: "MO", city: "Kansas City", country: "US", region: "Kansas City", coordinates: { lat: 39.0997, lng: -94.5786 } },
      "817" => { state: "TX", city: "Fort Worth", country: "US", region: "Dallas-Fort Worth", coordinates: { lat: 32.7555, lng: -97.3308 } },
      "818" => { state: "CA", city: "Burbank", country: "US", region: "San Fernando Valley", coordinates: { lat: 34.1808, lng: -118.3090 } },
      "819" => { state: "QC", city: "Sherbrooke", country: "CA", region: "Eastern Quebec", coordinates: { lat: 45.4042, lng: -71.8929 } },
      "828" => { state: "NC", city: "Asheville", country: "US", region: "Western North Carolina", coordinates: { lat: 35.5951, lng: -82.5515 } },
      "830" => { state: "TX", city: "New Braunfels", country: "US", region: "South Central Texas", coordinates: { lat: 29.7030, lng: -98.1245 } },
      "831" => { state: "CA", city: "Salinas", country: "US", region: "Monterey Bay", coordinates: { lat: 36.6777, lng: -121.6555 } },
      "832" => { state: "TX", city: "Houston", country: "US", region: "Houston Metro", coordinates: { lat: 29.7604, lng: -95.3698 } },
      "843" => { state: "SC", city: "Charleston", country: "US", region: "Coastal South Carolina", coordinates: { lat: 32.7765, lng: -79.9311 } },
      "845" => { state: "NY", city: "Poughkeepsie", country: "US", region: "Hudson Valley", coordinates: { lat: 41.7004, lng: -73.9209 } },
      "847" => { state: "IL", city: "Evanston", country: "US", region: "North Chicago Suburbs", coordinates: { lat: 42.0451, lng: -87.6877 } },
      "848" => { state: "NJ", city: "Toms River", country: "US", region: "Central New Jersey", coordinates: { lat: 39.9537, lng: -74.1979 } },
      "850" => { state: "FL", city: "Tallahassee", country: "US", region: "North Florida", coordinates: { lat: 30.4518, lng: -84.2807 } },
      "856" => { state: "NJ", city: "Camden", country: "US", region: "South Jersey", coordinates: { lat: 39.9259, lng: -75.1196 } },
      "857" => { state: "MA", city: "Boston", country: "US", region: "Boston Metro", coordinates: { lat: 42.3601, lng: -71.0589 } },
      "858" => { state: "CA", city: "San Diego", country: "US", region: "North San Diego County", coordinates: { lat: 32.7157, lng: -117.1611 } },
      "859" => { state: "KY", city: "Lexington", country: "US", region: "Central Kentucky", coordinates: { lat: 38.0406, lng: -84.5037 } },
      "860" => { state: "CT", city: "Hartford", country: "US", region: "Connecticut", coordinates: { lat: 41.7658, lng: -72.6734 } },
      "862" => { state: "NJ", city: "Newark", country: "US", region: "North Jersey", coordinates: { lat: 40.7357, lng: -74.1724 } },
      "863" => { state: "FL", city: "Lakeland", country: "US", region: "Central Florida", coordinates: { lat: 28.0395, lng: -81.9498 } },
      "864" => { state: "SC", city: "Greenville", country: "US", region: "Upstate South Carolina", coordinates: { lat: 34.8526, lng: -82.3940 } },
      "865" => { state: "TN", city: "Knoxville", country: "US", region: "East Tennessee", coordinates: { lat: 35.9606, lng: -83.9207 } },
      "870" => { state: "AR", city: "Jonesboro", country: "US", region: "Northeast Arkansas", coordinates: { lat: 35.8423, lng: -90.7043 } },
      "878" => { state: "PA", city: "Pittsburgh", country: "US", region: "Western Pennsylvania", coordinates: { lat: 40.4406, lng: -79.9959 } },
      "901" => { state: "TN", city: "Memphis", country: "US", region: "Memphis", coordinates: { lat: 35.1495, lng: -90.0490 } },
      "902" => { state: "NS", city: "Halifax", country: "CA", region: "Nova Scotia", coordinates: { lat: 44.6488, lng: -63.5752 } },
      "903" => { state: "TX", city: "Tyler", country: "US", region: "Northeast Texas", coordinates: { lat: 32.3513, lng: -95.3011 } },
      "904" => { state: "FL", city: "Jacksonville", country: "US", region: "Northeast Florida", coordinates: { lat: 30.3322, lng: -81.6557 } },
      "905" => { state: "ON", city: "Hamilton", country: "CA", region: "Golden Horseshoe", coordinates: { lat: 43.2557, lng: -79.8711 } },
      "906" => { state: "MI", city: "Marquette", country: "US", region: "Upper Peninsula", coordinates: { lat: 46.5436, lng: -87.3959 } },
      "907" => { state: "AK", city: "Anchorage", country: "US", region: "Alaska", coordinates: { lat: 61.2181, lng: -149.9003 } },
      "908" => { state: "NJ", city: "Elizabeth", country: "US", region: "Central New Jersey", coordinates: { lat: 40.6640, lng: -74.2107 } },
      "909" => { state: "CA", city: "San Bernardino", country: "US", region: "Inland Empire", coordinates: { lat: 34.1083, lng: -117.2898 } },
      "910" => { state: "NC", city: "Fayetteville", country: "US", region: "Southeast North Carolina", coordinates: { lat: 35.0527, lng: -78.8784 } },
      "912" => { state: "GA", city: "Savannah", country: "US", region: "Southeast Georgia", coordinates: { lat: 32.0835, lng: -81.0998 } },
      "913" => { state: "KS", city: "Overland Park", country: "US", region: "Kansas City Metro", coordinates: { lat: 38.9822, lng: -94.6708 } },
      "914" => { state: "NY", city: "White Plains", country: "US", region: "Westchester County", coordinates: { lat: 41.0340, lng: -73.7629 } },
      "915" => { state: "TX", city: "El Paso", country: "US", region: "West Texas", coordinates: { lat: 31.7619, lng: -106.4850 } },
      "916" => { state: "CA", city: "Sacramento", country: "US", region: "Sacramento", coordinates: { lat: 38.5816, lng: -121.4944 } },
      "917" => { state: "NY", city: "New York", country: "US", region: "NYC Mobile", coordinates: { lat: 40.7589, lng: -73.9851 } },
      "918" => { state: "OK", city: "Tulsa", country: "US", region: "Northeast Oklahoma", coordinates: { lat: 36.1540, lng: -95.9928 } },
      "919" => { state: "NC", city: "Raleigh", country: "US", region: "Research Triangle", coordinates: { lat: 35.7796, lng: -78.6382 } },
      "920" => { state: "WI", city: "Green Bay", country: "US", region: "Northeast Wisconsin", coordinates: { lat: 44.5133, lng: -88.0133 } },
      "925" => { state: "CA", city: "Concord", country: "US", region: "East Bay", coordinates: { lat: 37.9780, lng: -122.0311 } },
      "928" => { state: "AZ", city: "Flagstaff", country: "US", region: "Northern Arizona", coordinates: { lat: 35.1983, lng: -111.6513 } },
      "929" => { state: "NY", city: "New York", country: "US", region: "NYC Overlay", coordinates: { lat: 40.7589, lng: -73.9851 } },
      "931" => { state: "TN", city: "Clarksville", country: "US", region: "Middle Tennessee", coordinates: { lat: 36.5298, lng: -87.3595 } },
      "936" => { state: "TX", city: "Huntsville", country: "US", region: "East Texas", coordinates: { lat: 30.7235, lng: -95.5502 } },
      "937" => { state: "OH", city: "Dayton", country: "US", region: "Southwest Ohio", coordinates: { lat: 39.7589, lng: -84.1916 } },
      "940" => { state: "TX", city: "Wichita Falls", country: "US", region: "North Texas", coordinates: { lat: 33.9137, lng: -98.4934 } },
      "941" => { state: "FL", city: "Sarasota", country: "US", region: "Southwest Florida", coordinates: { lat: 27.3364, lng: -82.5307 } },
      "947" => { state: "MI", city: "Troy", country: "US", region: "Oakland County", coordinates: { lat: 42.6064, lng: -83.1498 } },
      "949" => { state: "CA", city: "Irvine", country: "US", region: "Orange County", coordinates: { lat: 33.6846, lng: -117.8265 } },
      "951" => { state: "CA", city: "Riverside", country: "US", region: "Inland Empire", coordinates: { lat: 33.9533, lng: -117.3961 } },
      "952" => { state: "MN", city: "Bloomington", country: "US", region: "Twin Cities South", coordinates: { lat: 44.8408, lng: -93.2982 } },
      "954" => { state: "FL", city: "Fort Lauderdale", country: "US", region: "Broward County", coordinates: { lat: 26.1224, lng: -80.1373 } },
      "956" => { state: "TX", city: "Laredo", country: "US", region: "South Texas", coordinates: { lat: 27.5306, lng: -99.4803 } },
      "959" => { state: "CT", city: "Hartford", country: "US", region: "Connecticut", coordinates: { lat: 41.7658, lng: -72.6734 } },
      "970" => { state: "CO", city: "Fort Collins", country: "US", region: "Northern Colorado", coordinates: { lat: 40.5853, lng: -105.0844 } },
      "971" => { state: "OR", city: "Portland", country: "US", region: "Oregon", coordinates: { lat: 45.5152, lng: -122.6784 } },
      "972" => { state: "TX", city: "Dallas", country: "US", region: "Dallas Metro", coordinates: { lat: 32.7767, lng: -96.7970 } },
      "973" => { state: "NJ", city: "Newark", country: "US", region: "North Jersey", coordinates: { lat: 40.7357, lng: -74.1724 } },
      "978" => { state: "MA", city: "Lowell", country: "US", region: "Northeast Massachusetts", coordinates: { lat: 42.6334, lng: -71.3162 } },
      "979" => { state: "TX", city: "College Station", country: "US", region: "East Central Texas", coordinates: { lat: 30.6280, lng: -96.3344 } },
      "980" => { state: "NC", city: "Charlotte", country: "US", region: "Charlotte Metro", coordinates: { lat: 35.2271, lng: -80.8431 } },
      "984" => { state: "NC", city: "Raleigh", country: "US", region: "Research Triangle", coordinates: { lat: 35.7796, lng: -78.6382 } },
      "985" => { state: "LA", city: "Hammond", country: "US", region: "Southeast Louisiana", coordinates: { lat: 30.5043, lng: -90.4612 } },
      "989" => { state: "MI", city: "Saginaw", country: "US", region: "Central Michigan", coordinates: { lat: 43.4194, lng: -83.9508 } }
    }

    area_code_map[area_code.to_s]
  end

  # United Kingdom
  def self.uk_area_codes(area_code)
    # UK area codes are typically 2-5 digits after the initial 0
    area_code_map = {
      "20" => { city: "London", region: "Greater London", country: "GB", coordinates: { lat: 51.5074, lng: -0.1278 } },
      "121" => { city: "Birmingham", region: "West Midlands", country: "GB", coordinates: { lat: 52.4862, lng: -1.8904 } },
      "131" => { city: "Edinburgh", region: "Scotland", country: "GB", coordinates: { lat: 55.9533, lng: -3.1883 } },
      "141" => { city: "Glasgow", region: "Scotland", country: "GB", coordinates: { lat: 55.8642, lng: -4.2518 } },
      "151" => { city: "Liverpool", region: "Merseyside", country: "GB", coordinates: { lat: 53.4084, lng: -2.9916 } },
      "161" => { city: "Manchester", region: "Greater Manchester", country: "GB", coordinates: { lat: 53.4808, lng: -2.2426 } },
      "191" => { city: "Newcastle", region: "North East England", country: "GB", coordinates: { lat: 54.9783, lng: -1.6178 } },
      "113" => { city: "Leeds", region: "West Yorkshire", country: "GB", coordinates: { lat: 53.8008, lng: -1.5491 } },
      "114" => { city: "Sheffield", region: "South Yorkshire", country: "GB", coordinates: { lat: 53.3811, lng: -1.4701 } },
      "115" => { city: "Nottingham", region: "Nottinghamshire", country: "GB", coordinates: { lat: 52.9548, lng: -1.1581 } },
      "116" => { city: "Leicester", region: "Leicestershire", country: "GB", coordinates: { lat: 52.6369, lng: -1.1398 } },
      "117" => { city: "Bristol", region: "South West England", country: "GB", coordinates: { lat: 51.4545, lng: -2.5879 } },
      "118" => { city: "Reading", region: "Berkshire", country: "GB", coordinates: { lat: 51.4543, lng: -0.9781 } },
      "1223" => { city: "Cambridge", region: "Cambridgeshire", country: "GB", coordinates: { lat: 52.2053, lng: 0.1218 } },
      "1865" => { city: "Oxford", region: "Oxfordshire", country: "GB", coordinates: { lat: 51.7520, lng: -1.2577 } },
      "1273" => { city: "Brighton", region: "East Sussex", country: "GB", coordinates: { lat: 50.8225, lng: -0.1372 } },
      "1234" => { city: "Bedford", region: "Bedfordshire", country: "GB", coordinates: { lat: 52.1360, lng: -0.4667 } },
      "1235" => { city: "Abingdon", region: "Oxfordshire", country: "GB", coordinates: { lat: 51.6712, lng: -1.2846 } },
      "1242" => { city: "Cheltenham", region: "Gloucestershire", country: "GB", coordinates: { lat: 51.8994, lng: -2.0783 } },
      "1243" => { city: "Chichester", region: "West Sussex", country: "GB", coordinates: { lat: 50.8367, lng: -0.7792 } },
      "1244" => { city: "Chester", region: "Cheshire", country: "GB", coordinates: { lat: 53.1906, lng: -2.8919 } },
      "1245" => { city: "Chelmsford", region: "Essex", country: "GB", coordinates: { lat: 51.7356, lng: 0.4685 } },
      "1246" => { city: "Chesterfield", region: "Derbyshire", country: "GB", coordinates: { lat: 53.2351, lng: -1.4213 } },
      "1248" => { city: "Bangor", region: "Wales", country: "GB", coordinates: { lat: 53.2280, lng: -4.1290 } },
      "1249" => { city: "Chippenham", region: "Wiltshire", country: "GB", coordinates: { lat: 51.4580, lng: -2.1158 } },
      "1250" => { city: "Blairgowrie", region: "Scotland", country: "GB", coordinates: { lat: 56.5919, lng: -3.3403 } }
    }

    area_code_map[area_code.to_s]
  end

  # Middle East Countries - UAE
  def self.uae_area_codes(area_code)
    area_code_map = {
      "2" => { city: "Abu Dhabi", region: "Abu Dhabi Emirate", country: "AE", coordinates: { lat: 24.4539, lng: 54.3773 } },
      "3" => { city: "Al Ain", region: "Abu Dhabi Emirate", country: "AE", coordinates: { lat: 24.2084, lng: 55.7501 } },
      "4" => { city: "Dubai", region: "Dubai Emirate", country: "AE", coordinates: { lat: 25.2048, lng: 55.2708 } },
      "6" => { city: "Sharjah", region: "Sharjah Emirate", country: "AE", coordinates: { lat: 25.3463, lng: 55.4209 } },
      "7" => { city: "Ras Al Khaimah", region: "Ras Al Khaimah Emirate", country: "AE", coordinates: { lat: 25.7893, lng: 55.9737 } },
      "9" => { city: "Fujairah", region: "Fujairah Emirate", country: "AE", coordinates: { lat: 25.1164, lng: 56.3262 } }
    }

    area_code_map[area_code.to_s]
  end

  # Saudi Arabia
  def self.saudi_arabia_area_codes(area_code)
    area_code_map = {
      "11" => { city: "Riyadh", region: "Riyadh Province", country: "SA", coordinates: { lat: 24.7136, lng: 46.6753 } },
      "12" => { city: "Jeddah", region: "Makkah Province", country: "SA", coordinates: { lat: 21.4858, lng: 39.1925 } },
      "13" => { city: "Dammam", region: "Eastern Province", country: "SA", coordinates: { lat: 26.4207, lng: 50.0888 } },
      "14" => { city: "Buraidah", region: "Al Qassim Province", country: "SA", coordinates: { lat: 26.3260, lng: 43.9750 } },
      "16" => { city: "Khamis Mushait", region: "Asir Province", country: "SA", coordinates: { lat: 18.3073, lng: 42.7295 } },
      "17" => { city: "Medina", region: "Al Madinah Province", country: "SA", coordinates: { lat: 24.5247, lng: 39.5692 } }
    }

    area_code_map[area_code.to_s]
  end

  # Qatar
  def self.qatar_area_codes(area_code)
    area_code_map = {
      "44" => { city: "Doha", region: "Doha Municipality", country: "QA", coordinates: { lat: 25.2854, lng: 51.5310 } },
      "40" => { city: "Al Rayyan", region: "Al Rayyan Municipality", country: "QA", coordinates: { lat: 25.2919, lng: 51.4244 } },
      "42" => { city: "Al Wakrah", region: "Al Wakrah Municipality", country: "QA", coordinates: { lat: 25.1658, lng: 51.6075 } }
    }

    area_code_map[area_code.to_s]
  end

  # Kuwait
  def self.kuwait_area_codes(area_code)
    area_code_map = {
      "2" => { city: "Kuwait City", region: "Capital Governorate", country: "KW", coordinates: { lat: 29.3759, lng: 47.9774 } },
      "23" => { city: "Hawalli", region: "Hawalli Governorate", country: "KW", coordinates: { lat: 29.3326, lng: 48.0281 } },
      "24" => { city: "Farwaniya", region: "Farwaniya Governorate", country: "KW", coordinates: { lat: 29.2775, lng: 47.9581 } }
    }

    area_code_map[area_code.to_s]
  end

  # Bahrain
  def self.bahrain_area_codes(area_code)
    area_code_map = {
      "17" => { city: "Manama", region: "Capital Governorate", country: "BH", coordinates: { lat: 26.2235, lng: 50.5876 } },
      "16" => { city: "Riffa", region: "Southern Governorate", country: "BH", coordinates: { lat: 26.1300, lng: 50.5550 } }
    }

    area_code_map[area_code.to_s]
  end

  # Oman
  def self.oman_area_codes(area_code)
    area_code_map = {
      "24" => { city: "Muscat", region: "Muscat Governorate", country: "OM", coordinates: { lat: 23.5859, lng: 58.4059 } },
      "25" => { city: "Salalah", region: "Dhofar Governorate", country: "OM", coordinates: { lat: 17.0151, lng: 54.0924 } },
      "26" => { city: "Sohar", region: "North Al Batinah Governorate", country: "OM", coordinates: { lat: 24.3574, lng: 56.7536 } }
    }

    area_code_map[area_code.to_s]
  end

  # Jordan
  def self.jordan_area_codes(area_code)
    area_code_map = {
      "6" => { city: "Amman", region: "Amman Governorate", country: "JO", coordinates: { lat: 31.9454, lng: 35.9284 } },
      "5" => { city: "Irbid", region: "Irbid Governorate", country: "JO", coordinates: { lat: 32.5556, lng: 35.8500 } },
      "3" => { city: "Zarqa", region: "Zarqa Governorate", country: "JO", coordinates: { lat: 32.0728, lng: 36.0876 } }
    }

    area_code_map[area_code.to_s]
  end

  # Lebanon
  def self.lebanon_area_codes(area_code)
    area_code_map = {
      "1" => { city: "Beirut", region: "Beirut Governorate", country: "LB", coordinates: { lat: 33.8938, lng: 35.5018 } },
      "4" => { city: "Zahle", region: "Beqaa Governorate", country: "LB", coordinates: { lat: 33.8463, lng: 35.9016 } },
      "7" => { city: "Tripoli", region: "North Governorate", country: "LB", coordinates: { lat: 34.4365, lng: 35.8498 } }
    }

    area_code_map[area_code.to_s]
  end

  # Israel
  def self.israel_area_codes(area_code)
    area_code_map = {
      "2" => { city: "Jerusalem", region: "Jerusalem District", country: "IL", coordinates: { lat: 31.7683, lng: 35.2137 } },
      "3" => { city: "Tel Aviv", region: "Tel Aviv District", country: "IL", coordinates: { lat: 32.0853, lng: 34.7818 } },
      "4" => { city: "Haifa", region: "Haifa District", country: "IL", coordinates: { lat: 32.7940, lng: 34.9896 } },
      "8" => { city: "Beersheba", region: "Southern District", country: "IL", coordinates: { lat: 31.2518, lng: 34.7915 } },
      "9" => { city: "Netanya", region: "Central District", country: "IL", coordinates: { lat: 32.3215, lng: 34.8532 } }
    }

    area_code_map[area_code.to_s]
  end

  # Turkey
  def self.turkey_area_codes(area_code)
    area_code_map = {
      "212" => { city: "Istanbul", region: "Istanbul Province", country: "TR", coordinates: { lat: 41.0082, lng: 28.9784 } },
      "216" => { city: "Istanbul (Asian)", region: "Istanbul Province", country: "TR", coordinates: { lat: 40.9579, lng: 29.0813 } },
      "312" => { city: "Ankara", region: "Ankara Province", country: "TR", coordinates: { lat: 39.9334, lng: 32.8597 } },
      "232" => { city: "Izmir", region: "Izmir Province", country: "TR", coordinates: { lat: 38.4192, lng: 27.1287 } },
      "224" => { city: "Bursa", region: "Bursa Province", country: "TR", coordinates: { lat: 40.1826, lng: 29.0665 } },
      "242" => { city: "Antalya", region: "Antalya Province", country: "TR", coordinates: { lat: 36.8841, lng: 30.7056 } }
    }

    area_code_map[area_code.to_s]
  end

  # Iran
  def self.iran_area_codes(area_code)
    area_code_map = {
      "21" => { city: "Tehran", region: "Tehran Province", country: "IR", coordinates: { lat: 35.6944, lng: 51.4215 } },
      "31" => { city: "Isfahan", region: "Isfahan Province", country: "IR", coordinates: { lat: 32.6546, lng: 51.6680 } },
      "71" => { city: "Shiraz", region: "Fars Province", country: "IR", coordinates: { lat: 29.5918, lng: 52.5837 } },
      "51" => { city: "Mashhad", region: "Razavi Khorasan Province", country: "IR", coordinates: { lat: 36.2605, lng: 59.6168 } },
      "41" => { city: "Tabriz", region: "East Azerbaijan Province", country: "IR", coordinates: { lat: 38.0962, lng: 46.2738 } }
    }

    area_code_map[area_code.to_s]
  end

  # Iraq
  def self.iraq_area_codes(area_code)
    area_code_map = {
      "1" => { city: "Baghdad", region: "Baghdad Governorate", country: "IQ", coordinates: { lat: 33.3128, lng: 44.3615 } },
      "30" => { city: "Najaf", region: "Najaf Governorate", country: "IQ", coordinates: { lat: 32.0011, lng: 44.3319 } },
      "40" => { city: "Erbil", region: "Erbil Governorate", country: "IQ", coordinates: { lat: 36.1911, lng: 44.0089 } },
      "60" => { city: "Basra", region: "Basra Governorate", country: "IQ", coordinates: { lat: 30.5034, lng: 47.7804 } }
    }

    area_code_map[area_code.to_s]
  end

  # Egypt
  def self.egypt_area_codes(area_code)
    area_code_map = {
      "2" => { city: "Cairo", region: "Cairo Governorate", country: "EG", coordinates: { lat: 30.0444, lng: 31.2357 } },
      "3" => { city: "Alexandria", region: "Alexandria Governorate", country: "EG", coordinates: { lat: 31.2001, lng: 29.9187 } },
      "65" => { city: "Luxor", region: "Luxor Governorate", country: "EG", coordinates: { lat: 25.6872, lng: 32.6396 } },
      "97" => { city: "Aswan", region: "Aswan Governorate", country: "EG", coordinates: { lat: 24.0889, lng: 32.8998 } }
    }

    area_code_map[area_code.to_s]
  end

  # Continue with other major countries...
  # I'll add a few more key ones for brevity

  # Germany
  def self.germany_area_codes(area_code)
    area_code_map = {
      "30" => { city: "Berlin", region: "Berlin", country: "DE", coordinates: { lat: 52.5200, lng: 13.4050 } },
      "40" => { city: "Hamburg", region: "Hamburg", country: "DE", coordinates: { lat: 53.5511, lng: 9.9937 } },
      "89" => { city: "Munich", region: "Bavaria", country: "DE", coordinates: { lat: 48.1351, lng: 11.5820 } },
      "221" => { city: "Cologne", region: "North Rhine-Westphalia", country: "DE", coordinates: { lat: 50.9375, lng: 6.9603 } },
      "69" => { city: "Frankfurt", region: "Hesse", country: "DE", coordinates: { lat: 50.1109, lng: 8.6821 } }
    }

    area_code_map[area_code.to_s]
  end

  # France
  def self.france_area_codes(area_code)
    area_code_map = {
      "1" => { city: "Paris", region: "Île-de-France", country: "FR", coordinates: { lat: 48.8566, lng: 2.3522 } },
      "2" => { city: "Rouen", region: "Normandy", country: "FR", coordinates: { lat: 49.4431, lng: 1.0993 } },
      "3" => { city: "Lyon", region: "Auvergne-Rhône-Alpes", country: "FR", coordinates: { lat: 45.7640, lng: 4.8357 } },
      "4" => { city: "Marseille", region: "Provence-Alpes-Côte d'Azur", country: "FR", coordinates: { lat: 43.2965, lng: 5.3698 } },
      "5" => { city: "Toulouse", region: "Occitania", country: "FR", coordinates: { lat: 43.6047, lng: 1.4442 } }
    }

    area_code_map[area_code.to_s]
  end

  # Japan
  def self.japan_area_codes(area_code)
    area_code_map = {
      "3" => { city: "Tokyo", region: "Tokyo", country: "JP", coordinates: { lat: 35.6762, lng: 139.6503 } },
      "6" => { city: "Osaka", region: "Osaka", country: "JP", coordinates: { lat: 34.6937, lng: 135.5023 } },
      "45" => { city: "Yokohama", region: "Kanagawa", country: "JP", coordinates: { lat: 35.4478, lng: 139.6425 } },
      "52" => { city: "Nagoya", region: "Aichi", country: "JP", coordinates: { lat: 35.1815, lng: 136.9066 } },
      "75" => { city: "Kyoto", region: "Kyoto", country: "JP", coordinates: { lat: 35.0116, lng: 135.7681 } }
    }

    area_code_map[area_code.to_s]
  end

  # Add more countries as needed...
  # This is a comprehensive foundation that can be extended

  # Default implementations for other countries
  def self.australia_area_codes(area_code)
    area_code_map = {
      "2" => { city: "Sydney", region: "New South Wales", country: "AU", coordinates: { lat: -33.8688, lng: 151.2093 } },
      "3" => { city: "Melbourne", region: "Victoria", country: "AU", coordinates: { lat: -37.8136, lng: 144.9631 } },
      "7" => { city: "Brisbane", region: "Queensland", country: "AU", coordinates: { lat: -27.4705, lng: 153.0260 } },
      "8" => { city: "Adelaide", region: "South Australia", country: "AU", coordinates: { lat: -34.9285, lng: 138.6007 } }
    }
    area_code_map[area_code.to_s]
  end

  def self.italy_area_codes(area_code)
    area_code_map = {
      "6" => { city: "Rome", region: "Lazio", country: "IT", coordinates: { lat: 41.9028, lng: 12.4964 } },
      "2" => { city: "Milan", region: "Lombardy", country: "IT", coordinates: { lat: 45.4642, lng: 9.1900 } },
      "81" => { city: "Naples", region: "Campania", country: "IT", coordinates: { lat: 40.8518, lng: 14.2681 } }
    }
    area_code_map[area_code.to_s]
  end

  def self.spain_area_codes(area_code)
    area_code_map = {
      "91" => { city: "Madrid", region: "Community of Madrid", country: "ES", coordinates: { lat: 40.4168, lng: -3.7038 } },
      "93" => { city: "Barcelona", region: "Catalonia", country: "ES", coordinates: { lat: 41.3851, lng: 2.1734 } },
      "95" => { city: "Seville", region: "Andalusia", country: "ES", coordinates: { lat: 37.3891, lng: -5.9845 } }
    }
    area_code_map[area_code.to_s]
  end

  # Add stub implementations for remaining countries to avoid errors
  def self.netherlands_area_codes(area_code); end
  def self.belgium_area_codes(area_code); end
  def self.switzerland_area_codes(area_code); end
  def self.austria_area_codes(area_code); end
  def self.sweden_area_codes(area_code); end
  def self.norway_area_codes(area_code); end
  def self.denmark_area_codes(area_code); end
  def self.finland_area_codes(area_code); end
  def self.ireland_area_codes(area_code); end
  def self.portugal_area_codes(area_code); end
  def self.south_korea_area_codes(area_code); end
  def self.china_area_codes(area_code); end
  def self.india_area_codes(area_code); end
  def self.pakistan_area_codes(area_code); end
  def self.bangladesh_area_codes(area_code); end
  def self.singapore_area_codes(area_code); end
  def self.malaysia_area_codes(area_code); end
  def self.thailand_area_codes(area_code); end
  def self.vietnam_area_codes(area_code); end
  def self.philippines_area_codes(area_code); end
  def self.indonesia_area_codes(area_code); end
  def self.brazil_area_codes(area_code); end
  def self.mexico_area_codes(area_code); end
  def self.argentina_area_codes(area_code); end
  def self.russia_area_codes(area_code); end
  def self.south_africa_area_codes(area_code); end
  def self.new_zealand_area_codes(area_code); end
end
