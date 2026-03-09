-- 1) Departing scheduled passengers by origin airport + airline
SELECT
  origin_airport_id                         AS origin_airport_id,
  origin                                   AS origin_airport_code,
  origin_city_name                          AS origin_city_name,
  airline_id                                AS airline_id,
  unique_carrier_name                       AS unique_carrier_name,
  SUM(passengers)                           AS total_departing_passengers
FROM bts.domestic_market
GROUP BY
  origin_airport_id,
  origin,
  origin_city_name,
  airline_id,
  unique_carrier_name
ORDER BY
  origin_airport_id,
  airline_id;

-- 2) Arriving scheduled passengers by destination airport + airline
SELECT
  dest_airport_id                           AS destination_airport_id,
  dest                                     AS destination_airport_code,
  dest_city_name                            AS destination_city_name,
  airline_id                                AS airline_id,
  unique_carrier_name                       AS unique_carrier_name,
  SUM(passengers)                           AS total_arriving_passengers
FROM bts.domestic_market
GROUP BY
  dest_airport_id,
  dest,
  dest_city_name,
  airline_id,
  unique_carrier_name
ORDER BY
  dest_airport_id,
  airline_id;
  
-- 3) Arriving + Departing scheduled passengers by destination airport + airline
SELECT
  airport_id,
  airport_code,
  city_name,
  airline_id,
  carrier_name,
  SUM(total_passengers) AS total_passengers
FROM (
  -- Departures
  SELECT
    origin_airport_id      AS airport_id,
    origin                AS airport_code,
    origin_city_name      AS city_name,
    airline_id            AS airline_id,
    unique_carrier_name   AS carrier_name,
    SUM(passengers)       AS total_passengers
  FROM bts.domestic_market
  WHERE `year` = 2019
  GROUP BY
    origin_airport_id, origin, origin_city_name, airline_id, unique_carrier_name

  UNION ALL

  -- Arrivals
  SELECT
    dest_airport_id        AS airport_id,
    dest                  AS airport_code,
    dest_city_name        AS city_name,
    airline_id            AS airline_id,
    unique_carrier_name   AS carrier_name,
    SUM(passengers)       AS total_passengers
  FROM bts.domestic_market
  WHERE `year` = 2019
  GROUP BY
    dest_airport_id, dest, dest_city_name, airline_id, unique_carrier_name
) x
WHERE airport_code = 'LAX'
GROUP BY
  airport_id,
  airport_code,
  city_name,
  airline_id,
  carrier_name
ORDER BY
  total_passengers DESC;