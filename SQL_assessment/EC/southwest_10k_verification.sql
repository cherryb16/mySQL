/* ============================================================
   Extra Credit: Verify a Southwest Airlines 10-K Claim Using SQL
   Airline: Southwest Airlines Co. (LUV)
   Filing:  2019 Annual Report (Form 10-K), fiscal year ended December 31, 2019
            Filed with the SEC on February 6, 2020
   Source:  Part I, Item 1. Business — "Company Overview" section, page 3
   ============================================================

   Claim from the 10-K:
   "Based on the most recent data available from the U.S. Department of
   Transportation (the 'DOT'), as of September 30, 2019, Southwest was the
   largest domestic air carrier in the United States, as measured by the
   number of domestic originating passengers boarded."

   Approach:
   The BTS Domestic Market table (T-100 data) is the same DOT dataset
   Southwest references. Each row represents a directional origin-destination
   market; the `passengers` column counts passengers who boarded at the origin.
   Summing passengers by carrier gives total domestic originating passengers.

   To match the "as of September 30, 2019" reference, we use year = 2019
   and quarter IN (1, 2, 3) — i.e., January through September.
   Filter: class = 'F' (scheduled passenger service only).
   ============================================================ */

SELECT
    unique_carrier AS carrier_code,
    unique_carrier_name AS carrier_name,
    SUM(passengers) AS originating_passengers,
    RANK() OVER (ORDER BY SUM(passengers) DESC) AS passenger_rank
FROM bts.domestic_market
WHERE year  = 2019
  AND quarter IN (1, 2, 3)
  AND class = 'F'
GROUP BY unique_carrier, unique_carrier_name
ORDER BY originating_passengers DESC
LIMIT 10;

/* ============================================================
   RESULTS:
   carrier_code  carrier_name                  originating_passengers  passenger_rank
   ------------  ----------------------------  ----------------------  --------------
   WN            Southwest Airlines Co.           118,226,756               1
   DL            Delta Air Lines Inc.             102,263,355               2
   AA            American Airlines Inc.            94,080,172               3
   UA            United Air Lines Inc.             65,781,180               4
   OO            SkyWest Airlines Inc.             30,573,398               5
   AS            Alaska Airlines Inc.              25,325,336               6
   B6            JetBlue Airways                   25,300,487               7
   NK            Spirit Air Lines                  22,850,516               8
   F9            Frontier Airlines Inc.            15,928,032               9
   YX            Republic Airline                  13,205,565              10

   INTERPRETATION:
   Southwest (WN) ranks #1 with 118.2M originating passengers through Q3 2019,
   ahead of Delta (102.3M) by ~16M passengers. The 10-K claim is confirmed.

   POSSIBLE DISCREPANCIES:
   - The 10-K says "as of September 30, 2019" — this means YTD through Q3.
     Using quarter IN (1,2,3) aligns with that window.
   - The 10-K claim may include near-international flights Southwest operates
     (Mexico, Caribbean), which are not in the domestic_market table. This
     could slightly understate Southwest's total relative to purely domestic
     carriers, but Southwest's network is overwhelmingly domestic.
   - Class = 'F' (scheduled service) is the appropriate filter; charter or
     codeshare traffic would use different class codes.
   ============================================================ */
