-- ============================================
-- 1.1 DATASET OVERVIEW
-- ============================================
SELECT 'Total Transactions' as Metric, COUNT(*) as Value FROM transactions
UNION ALL SELECT 'Total Customers', COUNT(DISTINCT customer_code) FROM transactions
UNION ALL SELECT 'Total Products', COUNT(DISTINCT product_code) FROM transactions
UNION ALL SELECT 'Total Markets', COUNT(DISTINCT market_code) FROM transactions
UNION ALL SELECT 'Date Range - Min', MIN(order_date) FROM transactions
UNION ALL SELECT 'Date Range - Max', MAX(order_date) FROM transactions;

-- ============================================
-- 1.2 YEARLY PERFORMANCE SNAPSHOT
-- ============================================
SELECT 
    YEAR(order_date) as Year,
    COUNT(*) as Transaction_Count,
    COUNT(DISTINCT customer_code) as Unique_Customers,
    COUNT(DISTINCT product_code) as Unique_Products,
    COUNT(DISTINCT market_code) as Unique_Markets,
    SUM(sales_qty) as Total_Quantity,
    SUM(sales_amount) as Total_Revenue,
    AVG(sales_amount) as Avg_Transaction_Value,
    SUM(sales_amount) / NULLIF(SUM(sales_qty), 0) as Avg_Unit_Price
FROM transactions
GROUP BY YEAR(order_date)
ORDER BY Year;

-- ============================================
-- 1.3 CURRENCY DISTRIBUTION (WITH CLEANING)
-- ============================================
SELECT 
    TRIM(currency) as currency_clean,
    COUNT(*) as Transaction_Count,
    SUM(sales_amount) as Total_Amount,
    AVG(sales_amount) as Avg_Amount,
    MIN(sales_amount) as Min_Amount,
    MAX(sales_amount) as Max_Amount
FROM transactions
GROUP BY TRIM(currency)
ORDER BY Transaction_Count DESC;

-- ============================================
-- 1.4 DUPLICATE CHECK (YOUR DATA HAS DUPLICATES!)
-- ============================================
SELECT 
    order_date, 
    customer_code, 
    product_code, 
    market_code, 
    sales_qty, 
    sales_amount,
    COUNT(*) as Duplicate_Count
FROM transactions
GROUP BY 
    order_date, 
    customer_code, 
    product_code, 
    market_code, 
    sales_qty, 
    sales_amount
HAVING COUNT(*) > 1
ORDER BY Duplicate_Count DESC, order_date;

-- ============================================
-- 1.5 DATA QUALITY CHECK
-- ============================================
SELECT 
    SUM(CASE WHEN customer_code IS NULL OR customer_code = '' THEN 1 ELSE 0 END) as Missing_Customer,
    SUM(CASE WHEN product_code IS NULL OR product_code = '' THEN 1 ELSE 0 END) as Missing_Product,
    SUM(CASE WHEN market_code IS NULL OR market_code = '' THEN 1 ELSE 0 END) as Missing_Market,
    SUM(CASE WHEN sales_qty <= 0 THEN 1 ELSE 0 END) as Zero_Negative_Qty,
    SUM(CASE WHEN sales_amount <= 0 THEN 1 ELSE 0 END) as Zero_Negative_Amount,
    SUM(CASE WHEN currency IS NULL OR currency = '' THEN 1 ELSE 0 END) as Missing_Currency
FROM transactions;
-- ============================================
-- 2.1 MONTHLY REVENUE TREND (USING DATE TABLE)
-- ============================================
SELECT 
    d.year,
    d.month_name,
    COUNT(DISTINCT t.customer_code) as Active_Customers,
    COUNT(*) as Transactions,
    SUM(t.sales_qty) as Units_Sold,
    SUM(t.sales_amount) as Revenue,
    LAG(SUM(t.sales_amount), 1) OVER (ORDER BY d.year, d.month_name) as Prev_Month_Revenue,
    (SUM(t.sales_amount) - LAG(SUM(t.sales_amount), 1) OVER (ORDER BY d.year, d.month_name)) / 
        NULLIF(LAG(SUM(t.sales_amount), 1) OVER (ORDER BY d.year, d.month_name), 0) * 100 as MoM_Growth
FROM transactions t
JOIN date d ON t.order_date = d.date
GROUP BY d.year, d.month_name
ORDER BY d.year, d.month_name;

-- ============================================
-- 2.2 YEARLY REVENUE WITH YoY GROWTH
-- ============================================
WITH YearlyRevenue AS (
    SELECT 
        YEAR(order_date) as Year,
        SUM(sales_amount) as Revenue
    FROM transactions
    GROUP BY YEAR(order_date)
)
SELECT 
    Year,
    Revenue,
    LAG(Revenue) OVER (ORDER BY Year) as Prev_Year_Revenue,
    Revenue - LAG(Revenue) OVER (ORDER BY Year) as YoY_Change,
    ((Revenue - LAG(Revenue) OVER (ORDER BY Year)) / NULLIF(LAG(Revenue) OVER (ORDER BY Year), 0)) * 100 as YoY_Growth_Percent,
    CASE 
        WHEN ((Revenue - LAG(Revenue) OVER (ORDER BY Year)) / NULLIF(LAG(Revenue) OVER (ORDER BY Year), 0)) * 100 < -20 
        THEN '🔴 CRITICAL DECLINE'
        WHEN ((Revenue - LAG(Revenue) OVER (ORDER BY Year)) / NULLIF(LAG(Revenue) OVER (ORDER BY Year), 0)) * 100 < 0 
        THEN '⚠️ DECLINE'
        ELSE '📈 GROWTH'
    END as Trend_Status
FROM YearlyRevenue
ORDER BY Year;

-- ============================================
-- 2.3 REVENUE DECLINE ANALYSIS (2020 CRISIS)
-- ============================================
SELECT 
    d.month_name,
    SUM(t.sales_amount) as Revenue_2020,
    LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name) as Prev_Month_Revenue,
    (SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) as MoM_Drop,
    ((SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) / 
        NULLIF(LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name), 0)) * 100 as MoM_Drop_Percent
FROM transactions t
JOIN date d ON t.order_date = d.date
WHERE d.year = 2020
GROUP BY d.month_name
ORDER BY d.month_name;
-- ============================================
-- 3.1 ACTIVE CUSTOMER ANALYSIS - MULTIPLE DEFINITIONS
-- ============================================

-- ACTIVE CUSTOMER DEFINITION 1: Active in Current Year (2020)
SELECT 
    'Active Customers 2020' as Metric,
    COUNT(DISTINCT t.customer_code) as Customer_Count,
    SUM(t.sales_amount) as Total_Revenue,
    SUM(t.sales_qty) as Total_Quantity,
    AVG(t.sales_amount) as Avg_Transaction_Value
FROM transactions t
JOIN date d ON t.order_date = d.date
WHERE d.year = 2020;

-- ACTIVE CUSTOMER DEFINITION 2: Active in Last 30 Days (Recency)
SELECT 
    'Active Customers - Last 30 Days' as Metric,
    COUNT(DISTINCT customer_code) as Customer_Count,
    SUM(sales_amount) as Revenue_Last_30_Days
FROM transactions
WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

-- ACTIVE CUSTOMER DEFINITION 3: Active in Last 90 Days (Quarterly)
SELECT 
    'Active Customers - Last 90 Days' as Metric,
    COUNT(DISTINCT customer_code) as Customer_Count,
    SUM(sales_amount) as Revenue_Last_90_Days
FROM transactions
WHERE order_date >= DATE_SUB(CURDATE(), INTERVAL 90 DAY);

-- ============================================
-- 3.2 DETAILED ACTIVE CUSTOMER LIST WITH METRICS
-- ============================================
SELECT 
    c.custmer_name,  -- Using custmer_name as specified
    c.customer_code,
    COUNT(t.order_date) as Transaction_Count,
    COUNT(DISTINCT YEAR(t.order_date)) as Years_Active,
    SUM(t.sales_qty) as Total_Units_Purchased,
    SUM(t.sales_amount) as Lifetime_Revenue,
    MAX(t.order_date) as Last_Purchase_Date,
    DATEDIFF(CURDATE(), MAX(t.order_date)) as Days_Since_Last_Purchase,
    MIN(t.order_date) as First_Purchase_Date,
    CASE 
        WHEN MAX(t.order_date) >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN '🟢 Active - Last 30 Days'
        WHEN MAX(t.order_date) >= DATE_SUB(CURDATE(), INTERVAL 90 DAY) THEN '🟡 Active - Last 90 Days'
        WHEN MAX(t.order_date) >= DATE_SUB(CURDATE(), INTERVAL 180 DAY) THEN '🟠 Lapsed - 6 Months'
        WHEN MAX(t.order_date) >= DATE_SUB(CURDATE(), INTERVAL 365 DAY) THEN '🔴 Lapsed - 1 Year'
        ELSE '⚫ Churned'
    END as Customer_Status,
    CASE 
        WHEN SUM(t.sales_amount) > 50000000 THEN 'Platinum'
        WHEN SUM(t.sales_amount) > 10000000 THEN 'Gold'
        WHEN SUM(t.sales_amount) > 5000000 THEN 'Silver'
        WHEN SUM(t.sales_amount) > 1000000 THEN 'Bronze'
        ELSE 'Regular'
    END as Customer_Tier
FROM customers c
JOIN transactions t ON c.customer_code = t.customer_code
GROUP BY c.custmer_name, c.customer_code
ORDER BY Lifetime_Revenue DESC;

-- ============================================
-- 3.3 MONTHLY ACTIVE CUSTOMER TREND (2020)
-- ============================================
SELECT 
    d.month_name,
    COUNT(DISTINCT t.customer_code) as Active_Customers,
    SUM(t.sales_amount) as Monthly_Revenue,
    SUM(t.sales_qty) as Monthly_Quantity,
    AVG(t.sales_amount) as Avg_Order_Value
FROM transactions t
JOIN date d ON t.order_date = d.date
WHERE d.year = 2020
GROUP BY d.month_name
ORDER BY d.month_name;

-- ============================================
-- 3.4 CUSTOMER REVENUE CONTRIBUTION (PARETO 80/20)
-- ============================================
WITH CustomerRevenue AS (
    SELECT 
        c.custmer_name,
        c.customer_code,
        SUM(t.sales_amount) as Revenue,
        SUM(SUM(t.sales_amount)) OVER () as Total_Revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(t.sales_amount) DESC) as Revenue_Rank
    FROM customers c
    JOIN transactions t ON c.customer_code = t.customer_code
    WHERE YEAR(t.order_date) = 2020
    GROUP BY c.custmer_name, c.customer_code
)
SELECT 
    custmer_name,
    Revenue,
    ROUND(Revenue * 100.0 / Total_Revenue, 2) as Revenue_Share_Percent,
    ROUND(SUM(Revenue * 100.0 / Total_Revenue) OVER (ORDER BY Revenue_Rank), 2) as Cumulative_Share,
    Revenue_Rank,
    CASE 
        WHEN Revenue_Rank <= 8 THEN 'Top 20% Customers'
        WHEN Revenue_Rank <= 19 THEN 'Middle 30% Customers'
        ELSE 'Bottom 50% Customers'
    END as Customer_Segment
FROM CustomerRevenue
ORDER BY Revenue_Rank;
-- ============================================
-- 3.5 CUSTOMER CHURN ANALYSIS - YEAR OVER YEAR
-- ============================================

-- CHURN DEFINITION: Customer was active in previous year but NOT active in current year
WITH YearlyActivity AS (
    SELECT 
        customer_code,
        MAX(CASE WHEN YEAR(order_date) = 2017 THEN 1 ELSE 0 END) as Active_2017,
        MAX(CASE WHEN YEAR(order_date) = 2018 THEN 1 ELSE 0 END) as Active_2018,
        MAX(CASE WHEN YEAR(order_date) = 2019 THEN 1 ELSE 0 END) as Active_2019,
        MAX(CASE WHEN YEAR(order_date) = 2020 THEN 1 ELSE 0 END) as Active_2020
    FROM transactions
    GROUP BY customer_code
)
SELECT 
    '2017-2018' as Period,
    SUM(Active_2017) as Customers_Start,
    SUM(Active_2018) as Customers_End,
    SUM(CASE WHEN Active_2017 = 1 AND Active_2018 = 0 THEN 1 ELSE 0 END) as Churned_Customers,
    ROUND(
        SUM(CASE WHEN Active_2017 = 1 AND Active_2018 = 0 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(Active_2017), 0), 
    2) as Churn_Rate_Percent
FROM YearlyActivity
UNION ALL
SELECT 
    '2018-2019' as Period,
    SUM(Active_2018),
    SUM(Active_2019),
    SUM(CASE WHEN Active_2018 = 1 AND Active_2019 = 0 THEN 1 ELSE 0 END),
    ROUND(
        SUM(CASE WHEN Active_2018 = 1 AND Active_2019 = 0 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(Active_2018), 0), 
    2)
FROM YearlyActivity
UNION ALL
SELECT 
    '2019-2020' as Period,
    SUM(Active_2019),
    SUM(Active_2020),
    SUM(CASE WHEN Active_2019 = 1 AND Active_2020 = 0 THEN 1 ELSE 0 END),
    ROUND(
        SUM(CASE WHEN Active_2019 = 1 AND Active_2020 = 0 THEN 1 ELSE 0 END) * 100.0 / 
        NULLIF(SUM(Active_2019), 0), 
    2)
FROM YearlyActivity;

-- ============================================
-- 3.6 DETAILED CHURN LIST - CUSTOMERS WHO LEFT
-- ============================================
WITH CustomerActivity AS (
    SELECT 
        c.custmer_name,
        c.customer_code,
        MAX(CASE WHEN YEAR(t.order_date) = 2019 THEN 1 ELSE 0 END) as Active_2019,
        MAX(CASE WHEN YEAR(t.order_date) = 2020 THEN 1 ELSE 0 END) as Active_2020,
        MAX(t.order_date) as Last_Purchase_Date,
        SUM(CASE WHEN YEAR(t.order_date) = 2019 THEN t.sales_amount ELSE 0 END) as Revenue_2019,
        SUM(CASE WHEN YEAR(t.order_date) = 2020 THEN t.sales_amount ELSE 0 END) as Revenue_2020,
        SUM(t.sales_amount) as Lifetime_Revenue
    FROM customers c
    JOIN transactions t ON c.customer_code = t.customer_code
    GROUP BY c.custmer_name, c.customer_code
)
SELECT 
    custmer_name,
    customer_code,
    Last_Purchase_Date,
    DATEDIFF(CURDATE(), Last_Purchase_Date) as Days_Since_Last_Purchase,
    Revenue_2019,
    Revenue_2020,
    Lifetime_Revenue,
    Revenue_2019 - Revenue_2020 as Revenue_Lost,
    CASE 
        WHEN Active_2019 = 1 AND Active_2020 = 0 THEN '🟠 Churned in 2020'
        WHEN Active_2019 = 0 AND Active_2020 = 1 THEN '🟢 Reactivated'
        WHEN Active_2019 = 1 AND Active_2020 = 1 THEN '🔵 Retained'
        ELSE '⚫ Other'
    END as Churn_Status
FROM CustomerActivity
WHERE Active_2019 = 1 AND Active_2020 = 0  -- Churned customers only
ORDER BY Revenue_2019 DESC;

-- ============================================
-- 3.7 CUSTOMER RETENTION RATE (COHORT ANALYSIS)
-- ============================================
WITH FirstPurchase AS (
    SELECT 
        customer_code,
        MIN(YEAR(order_date)) as Cohort_Year
    FROM transactions
    GROUP BY customer_code
),
YearlyActivity AS (
    SELECT 
        fp.Cohort_Year,
        YEAR(t.order_date) as Activity_Year,
        COUNT(DISTINCT t.customer_code) as Active_Customers
    FROM FirstPurchase fp
    JOIN transactions t ON fp.customer_code = t.customer_code
    GROUP BY fp.Cohort_Year, YEAR(t.order_date)
)
SELECT 
    Cohort_Year,
    MAX(CASE WHEN Activity_Year = Cohort_Year THEN Active_Customers END) as Year_0,
    MAX(CASE WHEN Activity_Year = Cohort_Year + 1 THEN Active_Customers END) as Year_1,
    MAX(CASE WHEN Activity_Year = Cohort_Year + 2 THEN Active_Customers END) as Year_2,
    MAX(CASE WHEN Activity_Year = Cohort_Year + 3 THEN Active_Customers END) as Year_3,
    ROUND(MAX(CASE WHEN Activity_Year = Cohort_Year + 1 THEN Active_Customers END) * 100.0 / 
        NULLIF(MAX(CASE WHEN Activity_Year = Cohort_Year THEN Active_Customers END), 0), 2) as Retention_Rate_Y1,
    ROUND(MAX(CASE WHEN Activity_Year = Cohort_Year + 2 THEN Active_Customers END) * 100.0 / 
        NULLIF(MAX(CASE WHEN Activity_Year = Cohort_Year THEN Active_Customers END), 0), 2) as Retention_Rate_Y2,
    ROUND(MAX(CASE WHEN Activity_Year = Cohort_Year + 3 THEN Active_Customers END) * 100.0 / 
        NULLIF(MAX(CASE WHEN Activity_Year = Cohort_Year THEN Active_Customers END), 0), 2) as Retention_Rate_Y3
FROM YearlyActivity
GROUP BY Cohort_Year
ORDER BY Cohort_Year;
-- ============================================
-- 4.1 MARKET PERFORMANCE OVERVIEW
-- ============================================
SELECT 
    t.market_code,
    m.markets_name,
    m.zone,
    COUNT(DISTINCT t.customer_code) as Customer_Count,
    COUNT(*) as Transaction_Count,
    SUM(t.sales_qty) as Total_Quantity,
    SUM(t.sales_amount) as Total_Revenue,
    AVG(t.sales_amount) as Avg_Transaction_Value,
    SUM(t.sales_amount) / NULLIF(SUM(t.sales_qty), 0) as Avg_Unit_Price,
    RANK() OVER (ORDER BY SUM(t.sales_amount) DESC) as Revenue_Rank,
    RANK() OVER (ORDER BY SUM(t.sales_qty) DESC) as Volume_Rank
FROM transactions t
LEFT JOIN markets m ON t.market_code = m.markets_code
GROUP BY t.market_code, m.markets_name, m.zone
ORDER BY Total_Revenue DESC;

-- ============================================
-- 4.2 MARKET SHARE ANALYSIS
-- ============================================
WITH MarketRevenue AS (
    SELECT 
        m.zone,
        m.markets_name,
        SUM(t.sales_amount) as Revenue,
        SUM(SUM(t.sales_amount)) OVER () as Total_Revenue
    FROM transactions t
    JOIN markets m ON t.market_code = m.markets_code
    WHERE YEAR(t.order_date) = 2020
    GROUP BY m.zone, m.markets_name
)
SELECT 
    zone,
    markets_name,
    Revenue,
    ROUND(Revenue * 100.0 / Total_Revenue, 2) as Market_Share_Percent,
    ROUND(SUM(Revenue * 100.0 / Total_Revenue) OVER (PARTITION BY zone ORDER BY Revenue DESC), 2) as Zone_Cumulative
FROM MarketRevenue
ORDER BY Revenue DESC;

-- ============================================
-- 4.3 UNDERPERFORMING MARKETS (SALES QTY < 5000)
-- ============================================
SELECT 
    m.markets_name,
    m.zone,
    SUM(t.sales_qty) as Total_Quantity,
    SUM(t.sales_amount) as Total_Revenue,
    COUNT(DISTINCT t.customer_code) as Customer_Count,
    COUNT(*) as Transaction_Count,
    MAX(t.order_date) as Last_Sale_Date,
    '⚠️ URGENT ATTENTION' as Status
FROM transactions t
JOIN markets m ON t.market_code = m.markets_code
WHERE YEAR(t.order_date) = 2020
GROUP BY m.markets_name, m.zone
HAVING SUM(t.sales_qty) < 5000
ORDER BY Total_Quantity;
-- ============================================
-- 5.1 PRODUCT PERFORMANCE OVERVIEW
-- ============================================
SELECT 
    t.product_code,
    p.product_type,
    COUNT(DISTINCT t.customer_code) as Customer_Count,
    COUNT(DISTINCT t.market_code) as Market_Count,
    SUM(t.sales_qty) as Total_Quantity,
    SUM(t.sales_amount) as Total_Revenue,
    AVG(t.sales_amount / NULLIF(t.sales_qty, 0)) as Avg_Selling_Price,
    RANK() OVER (ORDER BY SUM(t.sales_amount) DESC) as Revenue_Rank
FROM transactions t
LEFT JOIN products p ON t.product_code = p.product_code
GROUP BY t.product_code, p.product_type
ORDER BY Total_Revenue DESC;

-- ============================================
-- 5.2 BLANK/BLINK PRODUCT INVESTIGATION (CRITICAL)
-- ============================================
SELECT 
    'Blank Products' as Issue,
    COUNT(DISTINCT t.product_code) as Product_Count,
    COUNT(*) as Transaction_Count,
    SUM(t.sales_qty) as Units_Sold,
    SUM(t.sales_amount) as Revenue_Lost,
    MIN(t.order_date) as First_Occurrence,
    MAX(t.order_date) as Last_Occurrence
FROM transactions t
LEFT JOIN products p ON t.product_code = p.product_code
WHERE p.product_type IS NULL 
   OR t.product_code IS NULL 
   OR t.product_code = ''
   OR t.product_code NOT IN (SELECT DISTINCT product_code FROM products);

-
-- ============================================
-- 6.1 2020 REVENUE DECLINE BY MONTH
-- ============================================
SELECT 
    d.month_name,
    SUM(t.sales_amount) as Monthly_Revenue,
    SUM(t.sales_qty) as Monthly_Quantity,
    COUNT(DISTINCT t.customer_code) as Active_Customers,
    LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name) as Prev_Month_Revenue,
    (SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) as Revenue_Drop,
    ROUND(((SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) / 
        NULLIF(LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name), 0)) * 100, 2) as Drop_Percent,
    CASE 
        WHEN ((SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) / 
            NULLIF(LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name), 0)) * 100 < -10 
        THEN '🔴 CRITICAL'
        WHEN ((SUM(t.sales_amount) - LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name)) / 
            NULLIF(LAG(SUM(t.sales_amount)) OVER (ORDER BY d.month_name), 0)) * 100 < 0 
        THEN '⚠️ DECLINE'
        ELSE '📈 GROWTH'
    END as Status
FROM transactions t
JOIN date d ON t.order_date = d.date
WHERE d.year = 2020
GROUP BY d.month_name
ORDER BY d.month_name;

-- ============================================
-- 6.2 CUSTOMERS CONTRIBUTING TO DECLINE
-- ============================================
SELECT 
    c.custmer_name,
    SUM(CASE WHEN YEAR(t.order_date) = 2019 THEN t.sales_amount ELSE 0 END) as Revenue_2019,
    SUM(CASE WHEN YEAR(t.order_date) = 2020 THEN t.sales_amount ELSE 0 END) as Revenue_2020,
    SUM(CASE WHEN YEAR(t.order_date) = 2020 THEN t.sales_amount ELSE 0 END) - 
        SUM(CASE WHEN YEAR(t.order_date) = 2019 THEN t.sales_amount ELSE 0 END) as Revenue_Change,
    ROUND((SUM(CASE WHEN YEAR(t.order_date) = 2020 THEN t.sales_amount ELSE 0 END) - 
        SUM(CASE WHEN YEAR(t.order_date) = 2019 THEN t.sales_amount ELSE 0 END)) * 100.0 / 
        NULLIF(SUM(CASE WHEN YEAR(t.order_date) = 2019 THEN t.sales_amount ELSE 0 END), 0), 2) as Change_Percent
FROM customers c
JOIN transactions t ON c.customer_code = t.customer_code
GROUP BY c.custmer_name, c.customer_code
HAVING Revenue_2019 > 0
ORDER BY Revenue_Change
LIMIT 10;

-- ============================================
-- POWER BI MEASURES FOR DASHBOARD
-- ============================================

-- ============================================
-- 7.1 REVENUE MEASURES
-- ============================================

-- Revenue = SUM(transactions[sales_amount])
-- Sales Qty = SUM(transactions[sales_qty])

-- ============================================
-- 7.2 🔥 ACTIVE CUSTOMER MEASURES (CRITICAL)
-- ============================================

-- ACTIVE CUSTOMER DEFINITION 1: Purchased in selected period
Active Customers = CALCULATE( DISTINCTCOUNT(transactions[customer_code]),transactions[sales_amount] > 0)



-- ============================================
-- 7.3 📉 CHURN MEASURES
-- ============================================
-- Customers Active Previous Year
Customers Previous Year = 
CALCULATE(
    DISTINCTCOUNT(transactions[customer_code]),
    SAMEPERIODLASTYEAR('date'[date]),
    transactions[sales_amount] > 0
)
-- Customers Active Current Year
Customers Current Year = 
CALCULATE(
    DISTINCTCOUNT(transactions[customer_code]),
    transactions[sales_amount] > 0
)

-- Churned Customers
Churned Customers = 
VAR CurrentYearCustomers = [Customers Current Year]
VAR PreviousYearCustomers = [Customers Previous Year]
VAR RetainedCustomers = 
    CALCULATE(
        DISTINCTCOUNT(transactions[customer_code]),
        transactions[customer_code] IN 
            CALCULATETABLE(
                VALUES(transactions[customer_code]),
                SAMEPERIODLASTYEAR('date'[date])
            )
    )
RETURN
    PreviousYearCustomers - RetainedCustomers

-- Customer Churn Rate %
Customer Churn Rate % = 
DIVIDE(
    [Churned Customers],
    [Customers Previous Year],
    0
)

-- ============================================
-- 7.4 CUSTOMER SEGMENTATION
-- ============================================

Customer Tier = 
VAR CustomerRevenue = [Total Revenue INR]
RETURN
    SWITCH(
        TRUE(),
        CustomerRevenue > 50000000, "💎 Platinum",
        CustomerRevenue > 10000000, "🥇 Gold",
        CustomerRevenue > 5000000, "🥈 Silver",
        CustomerRevenue > 1000000, "🥉 Bronze",
        "📦 Regular"
    )

-- Customer Lifetime Value (LTV)
Customer LTV = 
DIVIDE(
    [Total Revenue INR],
    DATEDIFF(MIN(transactions[order_date]), MAX(transactions[order_date]), MONTH) + 1,
    0
)

-- ============================================
-- 7.5 MARKET MEASURES (17 ZONES)
-- ============================================

Market Share % = 
DIVIDE(
    [Total Revenue INR],
    CALCULATE([Total Revenue INR], ALL(markets)),
    0
)

Market Performance Status = 
VAR MarketQty = SUM(transactions[sales_qty])
RETURN
    SWITCH(
        TRUE(),
        MarketQty > 100000, "⚡ OVERDRIVE",
        MarketQty > 50000, "💪 STRONG",
        MarketQty > 20000, "📈 RISING",
        MarketQty > 5000, "🌱 GROWING",
        MarketQty > 0, "⚠️ LOW",
        "❌ NO SALES"
    )


