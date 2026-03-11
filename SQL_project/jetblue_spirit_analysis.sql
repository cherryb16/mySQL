/* ============================================================
	QUESTION 1
	In how many Origin & Destination markets did JetBlue (B6) and Spirit (NK)
	compete head-to-head from 2021-Q3 through 2022-Q2?
   ============================================================ */

-- Unique routes flown by JetBlue
CREATE OR REPLACE VIEW jetblue_unique AS
SELECT origin, dest, unique_carrier_name AS airline
FROM domestic_market
WHERE ((year = 2021 AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2)))
    AND class = 'F' AND unique_carrier_name = 'JetBlue Airways'
GROUP BY origin, dest, unique_carrier_name;

-- Unique routes flown by Spirit
CREATE OR REPLACE VIEW spirit_unique AS
SELECT origin, dest, unique_carrier_name AS airline
FROM domestic_market
WHERE ((year = 2021 AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2)))
    AND class = 'F' AND unique_carrier_name = 'Spirit Air Lines'
GROUP BY origin, dest, unique_carrier_name;

-- Routes where both carriers operated
CREATE OR REPLACE VIEW jetblue_and_spirit_routes AS
SELECT
    j.origin AS origin,
    j.dest AS dest,
    j.airline AS jetblue_airline,
    s.airline AS spirit_airline
FROM jetblue_unique AS j
INNER JOIN spirit_unique AS s
    USING (origin, dest);

SELECT COUNT(*) AS head_to_head_markets
FROM jetblue_and_spirit_routes;
-- Answer: 188
-- Driver: Hazel and Andrew

/* ============================================================
	QUESTION 2
	Pre-merger HHI for overlapping (head-to-head) markets.
	How many had HHI > 2,500, and what % is that?

	HHI = SUM(market_share_i ^ 2), share on 0–100 scale.
	Range: 0 (perfect competition) → 10,000 (monopoly).
   ============================================================ */

-- Total passengers per carrier per route
CREATE OR REPLACE VIEW tot_passengers_per_route AS
SELECT
    origin,
    dest,
    unique_carrier_name AS airline,
    SUM(passengers) AS tot_passengers
FROM domestic_market
WHERE class = 'F'
    AND ((year = 2021 AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2)))
GROUP BY origin, dest, unique_carrier_name;

-- Total passengers across all carriers per route (window function)
CREATE OR REPLACE VIEW tot_passengers_per_market AS
SELECT
    *,
    SUM(tot_passengers) OVER (PARTITION BY origin, dest) AS passengers_per_route
FROM tot_passengers_per_route;
-- Driver: Sarahi

-- Market share per carrier per route
CREATE OR REPLACE VIEW market_share AS
SELECT *,
    (100 * tot_passengers / passengers_per_route) AS market_share
FROM tot_passengers_per_market;

-- Pre-merger HHI per route
CREATE OR REPLACE VIEW route_hhi AS
SELECT
    origin,
    dest,
    SUM(market_share * market_share) AS HHI
FROM market_share
GROUP BY origin, dest
HAVING HHI IS NOT NULL;

-- HHI restricted to overlapping JetBlue/Spirit routes
CREATE OR REPLACE VIEW competing_route_hhi AS
SELECT
    j.origin AS origin,
    j.dest AS dest,
    ROUND(h.HHI) AS hhi
FROM jetblue_and_spirit_routes AS j
LEFT JOIN route_hhi AS h
    ON h.origin = j.origin AND h.dest = j.dest
ORDER BY hhi DESC;
-- Driver: Hazel

SELECT
    COUNT(*) AS num_markets,
    COUNT(CASE WHEN hhi > 2500 THEN 1 END) AS num_markets_above_2500,
    ROUND(100 * SUM(CASE WHEN hhi > 2500 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_above_2500
FROM competing_route_hhi;
-- Answer: Total Markets 188, Markets Above 2500 181, Percentage 96.28%
-- Driver: Brayden

/* ============================================================
	QUESTION 3
	Post-merger (hypothetical) HHI if the merger were approved.
	How many markets would be presumptively illegal?

	Simulation: Spirit passengers folded into JetBlue as one entity.
	Presumptively illegal = post HHI > 2,500 AND delta > 200.
   ============================================================ */

-- Combine Spirit passengers into JetBlue on overlapping routes
CREATE OR REPLACE VIEW merged_passengers AS
SELECT
    origin,
    dest,
    CASE WHEN airline = 'Spirit Air Lines' THEN 'JetBlue Airways' ELSE airline END AS merged_airline,
    SUM(tot_passengers) AS tot_passengers
FROM tot_passengers_per_route
GROUP BY origin, dest, merged_airline;

-- Total passengers per route post-merger
CREATE OR REPLACE VIEW merged_passengers_per_market AS
SELECT
    *,
    SUM(tot_passengers) OVER (PARTITION BY origin, dest) AS passengers_per_route
FROM merged_passengers;

-- Post-merger market share per carrier per route
CREATE OR REPLACE VIEW merged_market_share AS
SELECT *,
    (100 * tot_passengers / passengers_per_route) AS market_share
FROM merged_passengers_per_market;

-- Post-merger HHI per route
CREATE OR REPLACE VIEW merged_route_hhi AS
SELECT
    origin,
    dest,
    SUM(market_share * market_share) AS post_HHI
FROM merged_market_share
GROUP BY origin, dest
HAVING post_HHI IS NOT NULL;

-- Compare pre- and post-merger HHI on overlapping routes
CREATE OR REPLACE VIEW hhi_comparison AS
SELECT
    c.origin,
    c.dest,
    c.hhi AS pre_HHI,
    ROUND(m.post_HHI) AS post_HHI,
    ROUND(m.post_HHI) - c.hhi AS delta_HHI
FROM competing_route_hhi AS c
LEFT JOIN merged_route_hhi AS m
    ON m.origin = c.origin AND m.dest = c.dest;

SELECT
    COUNT(*) AS total_overlapping_markets,
    ROUND(AVG(pre_HHI), 2) AS avg_pre_merger_HHI,
    ROUND(AVG(post_HHI), 2) AS avg_post_merger_HHI,
    ROUND(AVG(delta_HHI), 2) AS avg_delta_HHI,
    SUM(CASE WHEN post_HHI > 2500 AND delta_HHI > 200 THEN 1 END) AS presumptively_illegal,
    ROUND(
        100.0 * SUM(CASE WHEN post_HHI > 2500 AND delta_HHI > 200 THEN 1 END)
        / COUNT(*), 2) AS pct_presumptively_illegal
FROM hhi_comparison;
-- Answer: Total Overlapping Markets: 188, Avg Pre-Merger HHI: 4716.13,
--         Avg Post-Merger HHI: 5615.82, Avg Delta HHI: 899.70,
--         Presumptively Illegal Markets: 90, Pct Presumptively Illegal: 47.87%
-- Driver: Brayden

/* ============================================================
	QUESTION 4
	Given the analysis, why did JetBlue continue to pursue
	the merger despite antitrust headwinds?
   ============================================================ 
   
   Answer
   JetBlue likely kept pursuing Spirit for strategic reasons that went beyond 
   the near-term legal risk. The merger offered immediate scale, including more 
   aircraft, crews, and route coverage, which could help JetBlue spread fixed 
   costs and compete more effectively against the Big 4 legacy carriers. It also 
   had a defensive logic: if Frontier acquired Spirit instead, a major low-cost 
   rival could become even stronger in JetBlue’s core leisure markets. JetBlue’s 
   public case was that expanding JetBlue service would produce broader fare 
   discipline and better consumer outcomes, even if Spirit as a standalone 
   ultra-low-cost carrier disappeared. Regulators, however, focused on that 
   exact tradeoff, since removing Spirit could reduce the very lowest fare 
   options in many overlapping markets and increase concentration, which is 
   consistent with the HHI results showing substantial antitrust concern.
*/
