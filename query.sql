USE wmf;
SELECT year, referer, geocoded_data['country_code'] AS country, uri_query, user_agent, COUNT(*) AS requests
FROM webrequest
WHERE year = 2015
AND month = 04
AND ((day = 20 AND hour = 3) OR (day = 21 AND hour = 9) OR (day = 23 AND hour = 23) OR (day = 25 AND hour = 15)
OR (day = 25 AND hour = 18))
AND uri_path = '/w/api.php'
AND uri_query RLIKE('action=opensearch')
AND webrequest_source IN('text','mobile')
AND http_status IN('200','304')
GROUP BY year, referer, geocoded_data['country_code'], uri_query, user_agent;
