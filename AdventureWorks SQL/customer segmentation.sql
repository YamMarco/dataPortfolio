WITH customer_details AS (
    SELECT
        pr.BusinessEntityID,
        CONCAT(pr.FirstName, ' ', pr.LastName) AS FullName,
        phn.PhoneNumber,
        edr.EmailAddress,
        adr.AddressLine1 AS Address,
        adr.City,
        spr.Name AS Region,
        crg.Name AS Country,
        CAST(dm.BirthDate AS DATE) AS BirthDate,
        -- Marital status
        CASE
            WHEN dm.MaritalStatus = 'M' THEN 'Married'
            WHEN dm.MaritalStatus = 'S' THEN 'Single'
        END AS MaritalStatus,
        dm.YearlyIncome,
        -- Gender
        CASE
            WHEN dm.Gender = 'M' THEN 'Male'
            WHEN dm.Gender = 'F' THEN 'Female'
        END AS Gender,
        dm.TotalChildren,
        dm.Education,
        dm.Occupation,
        dm.HomeOwnerFlag,
        dm.NumberCarsOwned
    FROM Person.Person pr
    LEFT JOIN Person.BusinessEntityAddress bdr ON bdr.BusinessEntityID = pr.BusinessEntityID
    left JOIN Person.Address adr ON bdr.AddressID = adr.AddressID
    left JOIN Person.StateProvince spr ON spr.StateProvinceID = adr.StateProvinceID
    left JOIN Person.CountryRegion crg ON crg.CountryRegionCode = spr.CountryRegionCode
    LEFT JOIN Person.PersonPhone phn ON phn.BusinessEntityID = pr.BusinessEntityID
    LEFT JOIN Person.EmailAddress edr ON edr.BusinessEntityID = pr.BusinessEntityID
    LEFT JOIN Sales.vPersonDemographics dm ON dm.BusinessEntityID = pr.BusinessEntityID
),
months_since_last_buy AS (
    SELECT
        CustomerID,
        DATEDIFF(MONTH, CAST(MAX(OrderDate) AS DATE), '2014-06-30') AS m_sinceOrdered
    FROM sales.SalesOrderHeader
    GROUP BY CustomerID
),
AOV_totalSales AS (
    SELECT 
		CustomerID, 
		CAST(SUM(subtotal) AS INT) AS total_sales
		,cast(sum(subtotal)/count(distinct SalesOrderID) as int) as aov
    FROM sales.SalesOrderHeader
    GROUP BY CustomerID
),
total_orders AS (
    SELECT CustomerID, COUNT(DISTINCT SalesOrderID) AS totalOrders
    FROM sales.SalesOrderHeader
    GROUP BY CustomerID
),
percentiles_base AS (
    SELECT 
        a.CustomerID,
        a.PersonID,
        NTILE(20) OVER (ORDER BY b.m_sinceOrdered ASC) AS tile_sinceOrdered,
        b.m_sinceOrdered,
        NTILE(20) OVER (ORDER BY c.total_sales DESC) AS tile_total_sales,
        c.total_sales,
		c.aov,
        NTILE(20) OVER (ORDER BY d.totalOrders DESC) AS tile_totalOrders,
        d.totalOrders
    FROM sales.Customer a
    LEFT JOIN months_since_last_buy b ON a.CustomerID = b.CustomerID
    LEFT JOIN AOV_totalSales c ON a.CustomerID = c.CustomerID
    LEFT JOIN total_orders d ON a.CustomerID = d.CustomerID
),
rfm_scores AS (
    SELECT 
        CustomerID,
        PersonID,
        -- Calculate frequency, monetary, and recency scores based on NTILE percentiles
        CASE 
            WHEN tile_totalOrders BETWEEN 1 AND 3 THEN 5
            WHEN tile_totalOrders BETWEEN 4 AND 5 THEN 4
            WHEN tile_totalOrders BETWEEN 6 AND 10 THEN 3
            WHEN tile_totalOrders BETWEEN 11 AND 15 THEN 2
            ELSE 1
        END AS frequency_score,
        CASE 
            WHEN tile_total_sales BETWEEN 1 AND 3 THEN 5
            WHEN tile_total_sales BETWEEN 4 AND 5 THEN 4
            WHEN tile_total_sales BETWEEN 6 AND 10 THEN 3
            WHEN tile_total_sales BETWEEN 11 AND 15 THEN 2
            ELSE 1
        END AS monetary_score,
        CASE 
            WHEN tile_sinceOrdered BETWEEN 1 AND 3 THEN 5
            WHEN tile_sinceOrdered BETWEEN 4 AND 5 THEN 4
            WHEN tile_sinceOrdered BETWEEN 6 AND 10 THEN 3
            WHEN tile_sinceOrdered BETWEEN 11 AND 15 THEN 2
            ELSE 1
        END AS recency_score
    FROM percentiles_base
),
scored_customers AS (
    SELECT 
        CustomerID,
        PersonID,
        recency_score,
        frequency_score,
        monetary_score,
        (recency_score + frequency_score + monetary_score) AS RFM_score
    FROM rfm_scores
),
ranked_customers AS (
    SELECT *,
        NTILE(100) OVER (ORDER BY RFM_score DESC) AS rfm_percentile
    FROM scored_customers
)



/*
--debug percetiles
select tile_total_sales, min(total_sales) as min_value
from percentiles_base
group by tile_total_sales
*/


/*
SELECT rc.customerID,
    -- Tier assignment based on percentile
    CASE 
        WHEN rfm_percentile <= 10 THEN 'Gold'
        WHEN rfm_percentile <= 25 THEN 'Silver'
        WHEN rfm_percentile <= 50 THEN 'Bronze'
        ELSE 'Regular'
    END AS rfm_tier,
    -- Dormant high-value segment
    CASE 
        WHEN frequency_score >= 4 AND monetary_score >= 4 AND recency_score <= 3 THEN 'High-Value Dormant'
        ELSE NULL
    END AS segment
	,'|' as _
	,   pb.m_sinceOrdered
       , pb.total_sales as totalSales
        ,pb.totalOrders
		,pb.aov
	,'|' as __
	,FullName,
        PhoneNumber,
        EmailAddress,
        Address,
        City,
        Region,
        Country,
        BirthDate,
		MaritalStatus,
        YearlyIncome,
		Gender,
        TotalChildren,
        Education,
        Occupation,
        HomeOwnerFlag,
        NumberCarsOwned
FROM ranked_customers rc
left join customer_details cusd on cusd.BusinessEntityID= rc.PersonID
left join percentiles_base pb on pb.CustomerID= rc.CustomerID

*/

/*
--debug if matches
select sum(subtotal) as totalSales
from sales.SalesOrderHeader
inner join sales.Customer on Customer.CustomerID=SalesOrderHeader.CustomerID
where SalesOrderHeader.CustomerID = 19822
*/

SELECT 
    CAST(COUNT(CASE WHEN order_count = 1 THEN 1 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) AS percent_single_order_customers
FROM (
    SELECT CustomerID, COUNT(SalesOrderID) AS order_count
    FROM sales.SalesOrderHeader
    GROUP BY CustomerID
) AS s1;


