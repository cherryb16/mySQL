-- ============================================================
-- JetBlue / Spirit Airlines Merger Antitrust Analysis
-- Data Source: BTS DB1B Origin & Destination Survey
--              Market-level files, 2021-Q3 through 2022-Q2
-- Carrier Codes: JetBlue = 'B6', Spirit = 'NK'
-- HHI thresholds (DOJ/FTC Horizontal Merger Guidelines):
--   < 1,500           Unconcentrated
--   1,500 – 2,500     Moderately Concentrated
--   > 2,500           Highly Concentrated (presumptively illegal)
--   delta > 200 AND post > 2,500 → merger presumptively anticompetitive
-- ============================================================


-- ============================================================
-- PART 0: Create and Populate the Flight Traffic Table
-- ============================================================

DROP TABLE IF EXISTS flight_traffic;

CREATE TABLE flight_traffic (
    Year       SMALLINT   NOT NULL,
    Quarter    TINYINT    NOT NULL,
    Origin     CHAR(3)    NOT NULL,   -- 3-letter IATA airport code
    Dest       CHAR(3)    NOT NULL,   -- 3-letter IATA airport code
    Carrier    VARCHAR(2) NOT NULL,   -- Reporting carrier (RPCarrier in DB1B)
    Passengers INT        NOT NULL DEFAULT 0,
    INDEX idx_period  (Year, Quarter),
    INDEX idx_od      (Origin, Dest),
    INDEX idx_carrier (Carrier)
);

-- ---------------------------------------------------------------
-- DATA LOADING INSTRUCTIONS
--
-- 1. Go to: https://www.transtats.bts.gov/Tables.asp?QO_VQ=EFD
--    (BTS "Origin and Destination Survey" — DB1B Market table)
--
-- 2. Download and unzip the CSV files for:
--      2021 Q3, 2021 Q4, 2022 Q1, 2022 Q2
--
-- 3. The DB1B Market CSV has many columns. We only need:
--      Year, Quarter, Origin, Dest, RPCarrier, Passengers
--
-- 4. Run LOAD DATA INFILE once per quarter (update path each time).
--    The column list below maps all CSV columns in order;
--    unwanted columns are loaded into throwaway variables (@var).
--
-- NOTE: If using MySQL Workbench, enable local infile:
--   SET GLOBAL local_infile = 1;
--   and connect with --local-infile=1
-- ---------------------------------------------------------------

/*
LOAD DATA LOCAL INFILE '/path/to/Origin_and_Destination_Survey_DB1BMarket_2021_3.csv'
INTO TABLE flight_traffic
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    @ItinID, @MktID, @SeqNum, @Coupons,
    Year, Quarter,
    Origin, @OriginAirportID, @OriginCityMarketID,
    @OriginCountry, @OriginStateFips, @OriginState, @OriginStateName, @OriginWac,
    Dest, @DestAirportID, @DestCityMarketID,
    @DestCountry, @DestStateFips, @DestState, @DestStateName, @DestWac,
    @AirportGroup, @WacGroup,
    @TkCarrierChange, @TkCarrierGroup, @OpCarrierChange, @OpCarrierGroup,
    Carrier,      -- RPCarrier column
    @TkCarrier, @OpCarrier,
    @BulkFare, Passengers,
    @MktFare, @MktDistance, @MktDistanceGroup, @MktMilesFlown,
    @NonStopMiles, @ItinGeoType, @MktGeoType
);
-- Repeat for 2021_4, 2022_1, and 2022_2 (update file path each time)
*/


-- ============================================================
-- QUESTION 1
-- In how many O&D markets did JetBlue (B6) and Spirit (NK)
-- compete head-to-head from 2021-Q3 through 2022-Q2?
--
-- Market = normalized airport pair (LEAST/GREATEST so that
-- LAX->JFK and JFK->LAX are treated as the same market).
-- ============================================================

WITH carriers_by_market AS (
    SELECT
        LEAST(Origin, Dest)    AS mkt_a,
        GREATEST(Origin, Dest) AS mkt_b,
        Carrier
    FROM flight_traffic
    WHERE ((Year = 2021 AND Quarter IN (3, 4))
        OR (Year = 2022 AND Quarter IN (1, 2)))
      AND Passengers > 0
    GROUP BY mkt_a, mkt_b, Carrier
)
SELECT COUNT(*) AS head_to_head_markets
FROM carriers_by_market b6
JOIN carriers_by_market nk
    ON  b6.mkt_a = nk.mkt_a
    AND b6.mkt_b = nk.mkt_b
WHERE b6.Carrier = 'B6'
  AND nk.Carrier = 'NK';


-- ============================================================
-- QUESTION 2
-- Pre-merger HHI for overlapping (head-to-head) markets.
-- How many markets had HHI > 2,500, and what % is that?
--
-- HHI = SUM(market_share_i ^ 2), where share is 0–100 scale.
-- Range: 0 (perfect competition) → 10,000 (pure monopoly).
-- ============================================================

WITH
-- Step 1: Aggregate passengers by normalized market and carrier
pax_by_market AS (
    SELECT
        LEAST(Origin, Dest)    AS mkt_a,
        GREATEST(Origin, Dest) AS mkt_b,
        Carrier,
        SUM(Passengers)        AS pax
    FROM flight_traffic
    WHERE ((Year = 2021 AND Quarter IN (3, 4))
        OR (Year = 2022 AND Quarter IN (1, 2)))
      AND Passengers > 0
    GROUP BY mkt_a, mkt_b, Carrier
),

-- Step 2: Identify markets served by BOTH JetBlue and Spirit
overlapping AS (
    SELECT DISTINCT b6.mkt_a, b6.mkt_b
    FROM   pax_by_market b6
    JOIN   pax_by_market nk
        ON  b6.mkt_a = nk.mkt_a
        AND b6.mkt_b = nk.mkt_b
    WHERE  b6.Carrier = 'B6'
      AND  nk.Carrier = 'NK'
),

-- Step 3: Total passengers per overlapping market (all carriers)
market_totals AS (
    SELECT p.mkt_a, p.mkt_b, SUM(p.pax) AS total_pax
    FROM   pax_by_market p
    JOIN   overlapping   o USING (mkt_a, mkt_b)
    GROUP BY p.mkt_a, p.mkt_b
),

-- Step 4: Each carrier's market share (%) within each overlapping market
market_shares AS (
    SELECT
        p.mkt_a,
        p.mkt_b,
        p.Carrier,
        (p.pax / t.total_pax * 100.0) AS share_pct
    FROM   pax_by_market p
    JOIN   market_totals t USING (mkt_a, mkt_b)
),

-- Step 5: HHI per market = SUM(share_pct²)
pre_merger_hhi AS (
    SELECT
        mkt_a,
        mkt_b,
        ROUND(SUM(share_pct * share_pct), 2) AS HHI
    FROM   market_shares
    GROUP BY mkt_a, mkt_b
)

SELECT
    COUNT(*)                                                          AS total_overlapping_markets,
    SUM(CASE WHEN HHI > 2500 THEN 1 ELSE 0 END)                     AS markets_above_2500,
    ROUND(
        100.0 * SUM(CASE WHEN HHI > 2500 THEN 1 ELSE 0 END) / COUNT(*),
        1)                                                            AS pct_above_2500,
    ROUND(AVG(HHI), 2)                                               AS avg_HHI,
    ROUND(MIN(HHI), 2)                                               AS min_HHI,
    ROUND(MAX(HHI), 2)                                               AS max_HHI
FROM pre_merger_hhi;

-- Optional: uncomment to see each overlapping market with its HHI
/*
... (same CTEs as above) ...
SELECT
    mkt_a, mkt_b,
    HHI,
    CASE
        WHEN HHI > 2500 THEN 'Highly Concentrated'
        WHEN HHI > 1500 THEN 'Moderately Concentrated'
        ELSE 'Unconcentrated'
    END AS concentration_level
FROM pre_merger_hhi
ORDER BY HHI DESC;
*/


-- ============================================================
-- QUESTION 3
-- Post-merger (hypothetical) HHI if the merger were approved.
-- How many overlapping markets would be presumptively illegal?
--
-- Simulation: NK passengers are folded into B6 (one combined carrier).
-- Presumptively illegal = post-merger HHI > 2,500 AND delta HHI > 200.
-- ============================================================

WITH
pax_by_market AS (
    SELECT
        LEAST(Origin, Dest)    AS mkt_a,
        GREATEST(Origin, Dest) AS mkt_b,
        Carrier,
        SUM(Passengers)        AS pax
    FROM flight_traffic
    WHERE ((Year = 2021 AND Quarter IN (3, 4))
        OR (Year = 2022 AND Quarter IN (1, 2)))
      AND Passengers > 0
    GROUP BY mkt_a, mkt_b, Carrier
),
overlapping AS (
    SELECT DISTINCT b6.mkt_a, b6.mkt_b
    FROM   pax_by_market b6
    JOIN   pax_by_market nk
        ON  b6.mkt_a = nk.mkt_a
        AND b6.mkt_b = nk.mkt_b
    WHERE  b6.Carrier = 'B6'
      AND  nk.Carrier = 'NK'
),

-- --- PRE-MERGER HHI ---
pre_totals AS (
    SELECT p.mkt_a, p.mkt_b, SUM(p.pax) AS total_pax
    FROM   pax_by_market p
    JOIN   overlapping   o USING (mkt_a, mkt_b)
    GROUP BY p.mkt_a, p.mkt_b
),
pre_shares AS (
    SELECT p.mkt_a, p.mkt_b,
           (p.pax / t.total_pax * 100.0) AS share_pct
    FROM   pax_by_market p
    JOIN   pre_totals    t USING (mkt_a, mkt_b)
),
pre_hhi AS (
    SELECT mkt_a, mkt_b,
           ROUND(SUM(share_pct * share_pct), 2) AS pre_HHI
    FROM   pre_shares
    GROUP BY mkt_a, mkt_b
),

-- --- POST-MERGER HHI (NK merged into B6) ---
merged_pax AS (
    SELECT
        mkt_a,
        mkt_b,
        CASE WHEN Carrier = 'NK' THEN 'B6' ELSE Carrier END AS merged_carrier,
        SUM(pax)                                             AS pax
    FROM   pax_by_market
    GROUP BY mkt_a, mkt_b, merged_carrier
),
post_totals AS (
    SELECT p.mkt_a, p.mkt_b, SUM(p.pax) AS total_pax
    FROM   merged_pax  p
    JOIN   overlapping o USING (mkt_a, mkt_b)
    GROUP BY p.mkt_a, p.mkt_b
),
post_shares AS (
    SELECT p.mkt_a, p.mkt_b,
           (p.pax / t.total_pax * 100.0) AS share_pct
    FROM   merged_pax  p
    JOIN   post_totals t USING (mkt_a, mkt_b)
),
post_hhi AS (
    SELECT mkt_a, mkt_b,
           ROUND(SUM(share_pct * share_pct), 2) AS post_HHI
    FROM   post_shares
    GROUP BY mkt_a, mkt_b
),

-- --- COMBINE PRE AND POST ---
hhi_comparison AS (
    SELECT
        pre.mkt_a,
        pre.mkt_b,
        pre.pre_HHI,
        post.post_HHI,
        ROUND(post.post_HHI - pre.pre_HHI, 2) AS delta_HHI
    FROM pre_hhi  pre
    JOIN post_hhi post USING (mkt_a, mkt_b)
)

SELECT
    COUNT(*)                                                               AS total_overlapping_markets,
    ROUND(AVG(pre_HHI),   2)                                              AS avg_pre_merger_HHI,
    ROUND(AVG(post_HHI),  2)                                              AS avg_post_merger_HHI,
    ROUND(AVG(delta_HHI), 2)                                              AS avg_delta_HHI,
    -- Presumptively anticompetitive: post HHI > 2,500 AND delta > 200
    SUM(CASE WHEN post_HHI > 2500 AND delta_HHI > 200 THEN 1 ELSE 0 END) AS presumptively_illegal,
    ROUND(
        100.0 * SUM(CASE WHEN post_HHI > 2500 AND delta_HHI > 200 THEN 1 ELSE 0 END) / COUNT(*),
        1)                                                                 AS pct_presumptively_illegal
FROM hhi_comparison;


-- ============================================================
-- QUESTION 4
-- Given the analysis, why did JetBlue continue to pursue
-- the merger despite antitrust headwinds?
-- ============================================================
/*
Despite the clear antitrust risks revealed by the HHI analysis, JetBlue had
compelling strategic reasons to pursue the merger aggressively.

JetBlue occupied an awkward competitive middle-ground: too large to match
Frontier or Spirit on pure price, and too small to compete on scale with the
Big Four (American, Delta, United, Southwest). Acquiring Spirit was the fastest
available path to escape that trap — it would have instantly doubled JetBlue's
fleet, expanded its route network into markets it could not enter organically,
and given it the purchasing scale needed to negotiate better terms with aircraft
manufacturers, airports, and fuel suppliers.

JetBlue also likely miscalculated the regulatory environment. Having weathered
earlier DOJ scrutiny (including its Northeast Alliance with American Airlines),
management may have believed that strategic divestitures — airport slot transfers,
route concessions to Allegiant and others — could neutralize antitrust concerns.
They framed the deal as net pro-competitive, arguing that a larger JetBlue would
extend the "JetBlue Effect" (lower fares, higher service quality) into markets
previously dominated by legacy carriers. That narrative underestimated the DOJ's
singular focus on preserving Spirit's unique role as an ultra-low-cost disruptor.

Finally, the deal's economics rewarded persistence: JetBlue had negotiated a
$70M reverse breakup fee payable to Spirit if the merger was blocked — a modest
number relative to the transformational upside if approved. Walking away early
would have meant absorbing reputational and strategic losses without any benefit.
So JetBlue bet that a federal judge might see things differently than the DOJ,
a gamble that ultimately did not pay off.
*/
