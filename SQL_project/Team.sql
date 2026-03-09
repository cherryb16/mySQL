-- ============================================================
-- QUESTION 1
-- In how many Origin & Destination markets did JetBlue (B6) and Spirit (NK)
-- compete head-to-head from 2021-Q3 through 2022-Q2?
-- ============================================================

-- How many unique scheduled passenger routes did JetBlue fly in 2019? 
CREATE OR REPLACE VIEW jetblue_unique AS
SELECT origin, dest, unique_carrier_name AS airline
FROM domestic_market
WHERE ((year = '2021' AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2)))
    AND class='F' AND unique_carrier_name='JetBlue Airways'
GROUP BY origin, dest;

-- How many unique scheduled passenger routes did Spirit Airlines fly in 2019? 
CREATE OR REPLACE VIEW spirit_unique AS
SELECT origin, dest, unique_carrier_name AS airline
FROM domestic_market
WHERE ((year = '2021' AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2)))
    AND class='F' AND unique_carrier_name='Spirit Air Lines'
GROUP BY origin, dest;

-- How many scheduled passenger routes did JetBlue share with Spirit in 2019? 
CREATE OR REPLACE VIEW jetblue_and_spirit_routes AS
SELECT	j.dest as dest,
    s.origin as origin,
    j.airline as ja,
    s.airline as sa
FROM jetblue_unique AS j
INNER JOIN spirit_unique AS s
USING (origin, dest);

SELECT COUNT(*)
FROM jetblue_and_spirit_routes;

-- Answer: 188
-- Driver: Hazel and Andrew

-- ============================================================
-- QUESTION 2
-- Pre-merger HHI for overlapping (head-to-head) markets.
-- How many had HHI > 2,500, and what % is that?
--
-- HHI = SUM(market_share_i ^ 2), share on 0–100 scale.
-- Range: 0 (perfect competition) → 10,000 (monopoly).
-- ============================================================

CREATE OR REPLACE VIEW tot_passsengers_per_route AS
SELECT origin, 
	dest, 
    unique_carrier_name AS airline,
    SUM(passengers) AS tot_passengers
FROM domestic_market
WHERE class = 'F' AND ((year = '2021' AND (quarter = 3 OR quarter = 4)) OR (year = 2022 AND (quarter = 1 OR quarter = 2))) 
GROUP BY origin, dest, unique_carrier_name;

CREATE OR REPLACE VIEW tot_passengers_per_market AS
SELECT 
	*,
    SUM(tot_passengers) OVER(PARTITION BY origin,dest) AS passengers_per_route
FROM tot_passsengers_per_route; 

-- Driver: Sarahi

CREATE OR REPLACE VIEW market_share AS
SELECT *,
	(100*tot_passengers/passengers_per_route) AS market_share
FROM tot_passengers_per_market;

CREATE OR REPLACE VIEW route_hhi AS
SELECT origin,
	dest,
	SUM(market_share*market_share) AS HHI
FROM market_share
GROUP BY origin, dest
HAVING HHI IS NOT NULL;

CREATE OR REPLACE VIEW competing_route_hhi AS
SELECT j.origin AS jo,
	j.dest AS jd,
    h.origin AS origin,
    h.dest AS dest,
    ROUND(h.HHI) AS hhi
FROM jetblue_and_spirit_routes AS j
LEFT JOIN route_hhi AS h
ON h.origin=j.origin AND h.dest=j.dest
ORDER BY hhi DESC;

-- Driver: Hazel 

SELECT 
    COUNT(*) AS num_markets, 
    COUNT(CASE WHEN hhi > 2500 THEN 1 END) AS num_markets_above_2500,
    ROUND(100*SUM(CASE WHEN hhi > 2500 THEN 1 ELSE 0 END)/COUNT(*),2) AS pct_above_2500
FROM competing_route_hhi;

-- Driver: Brayden

-- ============================================================
-- QUESTION 3
-- Post-merger (hypothetical) HHI if the merger were approved.
-- How many markets would be presumptively illegal?
--
-- Simulation: NK passengers folded into B6 as one entity.
-- Presumptively illegal = post HHI > 2,500 AND delta > 200.
-- ============================================================


-- Given your analysis, why do you think JetBlue continued to pursue the merger? This is an open-ended question that cannot be 
-- directly answered from the case study. However, I would like your team to outline your thoughts in a brief paragraph so that you are 
-- prepared for our class discussion.