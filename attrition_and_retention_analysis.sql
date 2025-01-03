---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Project: Attrition & Retention Analysis
-- Objective: This project focuses on identifying key trends, patterns, and opportunities related to customer attrition (churn) and retention.
-- Approach: The analysis is performed across multiple dimensions, including customer demographics, engagement, adoption, industries, and representatives. 
-- The goal is to uncover actionable insights to improve retention rates and capitalize on upselling opportunities.  

-- Key Deliverables:
-- 1. Churn Analysis: Highlight the primary factors driving customer attrition, segmented by industry, loss reasons, and representatives.  
-- 2. Engagement & Adoption: Explore how engagement and adoption metrics correlate with churn and retention.
-- 3. Retention Insights: Identify characteristics of retained entities and evaluate potential upsell opportunities.
-- 4. Industry Performance: Assess industries requiring targeted interventions for improved retention.
-- 5. Representative Performance: Evaluate representatives with high churn rates to recommend focused training or support.
-- 6. Strategic Recommendations: Provide actionable takeaways to guide retention and revenue growth strategies.  
---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 1: Identify Churned Opportunities/Accounts
-- Objective: Fetch and analyze churned records to identify trends or patterns.
-- Attributes analyzed include Loss Reason, Industry, Age, Engagement, Adoption, and Type.
-- Additional insights: Calculate average and maximum engagement/adoption per industry 
-- and loss reason, alongside counts of churned records.

WITH ChurnedData AS (
    SELECT 
        ID,
        Name,
        Loss_Reason,
        Industry,
        Age AS Account_Age_In_Days,
        Engagement AS Engagement_Percentage,
        Adoption AS Product_Adoption_Percentage,
        Type,
        Churn
    FROM 
        PORTFOLIO.PUBLIC.CRM_DATA
    WHERE 
        Churn = 'Yes'
)
SELECT 
    Industry,
    Loss_Reason,
    COUNT(*) AS Total_Churned_Records,
    ROUND(AVG(Account_Age_In_Days),0) AS Avg_Account_Age,
    MAX(Account_Age_In_Days) AS Max_Account_Age,
    ROUND(AVG(Engagement_Percentage),1) AS Avg_Engagement_Percentage,
    MAX(Engagement_Percentage) AS Max_Engagement_Percentage,
    ROUND(AVG(Product_Adoption_Percentage),1) AS Avg_Adoption_Percentage,
    MAX(Product_Adoption_Percentage) AS Max_Adoption_Percentage
FROM 
    ChurnedData
GROUP BY 
    Industry, Loss_Reason
ORDER BY 
    Industry, Total_Churned_Records DESC, Loss_Reason;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 2: Analyze Churn Reasons by Industry
-- Objective: Categorize and analyze churn reasons by industry with additional insights. 
-- This helps identify the primary drivers of churn and their proportional impact.
WITH ChurnedData AS (
    SELECT 
        Industry,
        CASE 
            WHEN Loss_Reason IN ('Pricing', 'Cost') THEN 'Cost-Related'
            WHEN Loss_Reason IN ('Support', 'Service') THEN 'Service-Related'
            WHEN Loss_Reason IN ('Features', 'Product Fit') THEN 'Product-Related'
            ELSE 'Other'
        END AS Categorized_Reason,
        Loss_Reason,
        COUNT(*) OVER (PARTITION BY Industry) AS Total_Churned_In_Industry
    FROM 
        PORTFOLIO.PUBLIC.CRM_DATA
    WHERE 
        Churn = 'Yes'
),
ReasonCounts AS (
    SELECT 
        Industry,
        Categorized_Reason,
        Loss_Reason,
        COUNT(*) AS Occurrences,
        MAX(Total_Churned_In_Industry) AS Total_Churned_In_Industry
    FROM 
        ChurnedData
    GROUP BY 
        Industry, Categorized_Reason, Loss_Reason
)
SELECT 
    Industry,
    Categorized_Reason,
    Occurrences,
    Total_Churned_In_Industry,
    ROUND((Occurrences * 100.0 / Total_Churned_In_Industry), 2) AS Percentage_Of_Churn
FROM 
    ReasonCounts
ORDER BY 
    Industry, Percentage_Of_Churn DESC, Occurrences DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 3: Assess Engagement Levels vs. Churn
-- Objective: Compare average engagement levels and distributions for churned vs. non-churned entities. 
-- This identifies whether engagement levels correlate with churn and helps prioritize retention efforts.
WITH EngagementAnalysis AS (
    SELECT 
        Churn,
        Engagement,
        CASE 
            WHEN Engagement < 30 THEN 'Low'
            WHEN Engagement BETWEEN 30 AND 70 THEN 'Medium'
            ELSE 'High'
        END AS Engagement_Level
    FROM 
        PORTFOLIO.PUBLIC.CRM_DATA
),
AggregatedMetrics AS (
    SELECT 
        Churn,
        Engagement_Level,
        AVG(Engagement) AS Average_Engagement_Percentage,
        MIN(Engagement) AS Min_Engagement,
        MAX(Engagement) AS Max_Engagement,
        COUNT(*) AS Entity_Count
    FROM 
        EngagementAnalysis
    GROUP BY 
        Churn, Engagement_Level
)
SELECT 
    Churn,
    Engagement_Level,
    Average_Engagement_Percentage,
    Min_Engagement,
    Max_Engagement,
    Entity_Count,
    ROUND((Entity_Count * 100.0 / SUM(Entity_Count) OVER (PARTITION BY Churn)), 2) AS Percentage_In_Group
FROM 
    AggregatedMetrics
ORDER BY 
    Churn, Engagement_Level DESC, Percentage_In_Group DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 4: Evaluate Product Adoption and Churn
-- Objective: Perform a detailed analysis of product adoption levels for churned vs. non-churned entities.
-- This includes average, median, and distribution of product adoption percentages.
WITH AdoptionMetrics AS (
    SELECT 
        Churn,
        COUNT(*) AS Total_Entities,
        AVG(Adoption) AS Avg_Adoption_Percentage,
        MEDIAN(Adoption) OVER (PARTITION BY Churn) AS Median_Adoption,
        MIN(Adoption) OVER (PARTITION BY Churn) AS Min_Adoption,
        MAX(Adoption) OVER (PARTITION BY Churn) AS Max_Adoption,
        NTILE(4) OVER (PARTITION BY Churn ORDER BY Adoption) AS Quartile
    FROM 
        PORTFOLIO.PUBLIC.CRM_DATA
    GROUP BY 
        Churn, Adoption
)
SELECT 
    Churn,
    AVG(Avg_Adoption_Percentage) AS Average_Product_Adoption,
    MAX(Median_Adoption) AS Median_Product_Adoption,
    MAX(Max_Adoption) AS Highest_Product_Adoption,
    MIN(Min_Adoption) AS Lowest_Product_Adoption,
    Quartile,
    COUNT(*) AS Entities_Per_Quartile
FROM 
    AdoptionMetrics
GROUP BY 
    Churn, Quartile
ORDER BY 
    Churn, Quartile;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 5: Retention Analysis for Non-Churned Entities
-- Objective: Identify common characteristics of entities that have not churned, focusing on high engagement and adoption.
-- This analysis includes rankings, segmentation, and descriptive statistics for deeper insights.
WITH RetentionMetrics AS (
    SELECT 
        ID,
        Name,
        Industry,
        Age AS Account_Age_In_Days,
        Engagement AS Engagement_Percentage,
        Adoption AS Product_Adoption_Percentage,
        Type,
        Plan,
        NTILE(4) OVER (ORDER BY Engagement DESC) AS Engagement_Quartile,
        NTILE(4) OVER (ORDER BY Adoption DESC) AS Adoption_Quartile,
        ROW_NUMBER() OVER (PARTITION BY Industry ORDER BY Engagement DESC, Adoption DESC) AS Rank_Within_Industry
    FROM 
        PORTFOLIO.PUBLIC.CRM_DATA
    WHERE 
        Churn = 'No'
)
SELECT 
    ID,
    Name,
    Industry,
    Account_Age_In_Days,
    Engagement_Percentage,
    Product_Adoption_Percentage,
    Type,
    Plan,
    Engagement_Quartile,
    Adoption_Quartile,
    Rank_Within_Industry
FROM 
    RetentionMetrics
WHERE 
    Rank_Within_Industry <= 5 -- Focus on top 5 entities by engagement and adoption within each industry
ORDER BY 
    Industry, Rank_Within_Industry ASC, Engagement_Quartile ASC, Adoption_Quartile ASC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 6: Churn by Representative (Owner)
-- Objective: Group churned entities by owner and calculate churn rates for each representative.
-- This helps evaluate if certain owners have higher churn rates and understand their potential impact on retention.
SELECT 
    R.Owner,
    COUNT(C.ID) AS Churned_Entities,
    ROUND((COUNT(C.ID) / (SELECT COUNT(*) FROM PORTFOLIO.PUBLIC.CRM_DATA WHERE Churn = 'Yes')),2) AS Churn_Rate_Percentage
FROM 
    PORTFOLIO.PUBLIC.CRM_DATA C
JOIN 
    PORTFOLIO.PUBLIC.REP_DATA R
    ON C.ID = R.ID
WHERE 
    C.Churn = 'Yes'
GROUP BY 
    R.Owner
ORDER BY 
    Churn_Rate_Percentage DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 7: Top 3 Churn Reasons by Representative (Owner)  
-- Objective: Identify the top 3 churn reasons for each representative by analyzing the frequency of churn causes.  
-- This helps understand key factors contributing to churn under each owner and enables targeted interventions to reduce attrition. 
WITH ReasonCounts AS (
    SELECT 
        R.Owner,
        C.Loss_Reason,
        COUNT(Loss_Reason) AS Reason_Count
    FROM
        PORTFOLIO.PUBLIC.REP_DATA R
    JOIN 
        PORTFOLIO.PUBLIC.CRM_DATA C ON R.ID = C.ID
    WHERE 
        C.Loss_Reason != 'N/A'
    GROUP BY 
        R.Owner, C.Loss_Reason
),
RankedReasons AS (
    SELECT 
        Owner,
        Loss_Reason,
        Reason_Count,
        ROW_NUMBER() OVER (PARTITION BY Owner ORDER BY Reason_Count DESC) AS Rank
    FROM 
        ReasonCounts
)
SELECT 
    Owner,
    Loss_Reason,
    Reason_Count
FROM 
    RankedReasons
WHERE 
    Rank <= 3
ORDER BY 
    Owner, Rank;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 8: Segmented Analysis (Opportunity vs. Account)
-- Objective: Break down churn by entity type (Opportunity vs. Account) to understand if churn rates differ.
-- This segmentation helps create tailored retention strategies for Opportunities and Accounts.
SELECT 
    Type,
    COUNT(*) AS Total_Churned,
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM PORTFOLIO.PUBLIC.CRM_DATA WHERE Churn = 'Yes')),1) AS Churn_Percentage
FROM 
    PORTFOLIO.PUBLIC.CRM_DATA
WHERE 
    Churn = 'Yes'
GROUP BY 
    Type
ORDER BY 
    Churn_Percentage DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 9: Identify Opportunities for Upselling
-- Objective: Find non-churned entities with high engagement and adoption, signaling upsell potential.
-- These entities are likely to be good candidates for further expansion or feature adoption.
SELECT 
    ID,
    Name,
    Engagement AS Engagement_Percentage,
    Adoption AS Product_Adoption_Percentage,
    Type,
    Plan,
FROM 
    PORTFOLIO.PUBLIC.CRM_DATA
WHERE 
    Churn = 'No' 
    AND Engagement >= 70 
    AND Adoption >= 70
ORDER BY 
    Engagement DESC, Adoption DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- Question 10: Least Performing Verticals by Engagement & Adoption
-- Objective: Identify industries (verticals) with below-average engagement and adoption levels among churned entities.
-- This analysis highlights verticals that may require targeted interventions to improve customer satisfaction and retention.
WITH AverageEngagementByIndustry AS(
SELECT
    Industry,
    AVG(Engagement) AS Average_Engagement,
    AVG(Adoption) AS Average_Adoption
FROM
    PORTFOLIO.PUBLIC.CRM_DATA
WHERE 
    Churn = 'Yes'
GROUP BY 
    Industry
ORDER BY Average_Engagement ASC, Average_Adoption ASC
),

AverageEngagement AS (
SELECT 
    AVG(Average_Engagement) AS Average_Engagement,
    AVG(Average_Adoption) AS Average_Adoption
FROM 
    AverageEngagementByIndustry
)

SELECT
    Industry,
    AVG(Engagement) AS Average_Engagement,
    AVG(Adoption) AS Average_Adoption
FROM
    PORTFOLIO.PUBLIC.CRM_DATA
WHERE 
    Churn = 'Yes'
GROUP BY 
    Industry
HAVING AVG(ENGAGEMENT) < 
            (
            SELECT 
                Average_Engagement
            FROM
                AverageEngagement
            );

---------------------------------------------------------------------------------------------------------------------------------------------------------

-- SUMMARY/CONCLUSION : 

-- TAKEAWAY: ATTRITION
-- 1. Low product adoption (=<47.5%) and engagement levels (=<47.2%) are strongly correlated with churn. Retaining accounts with declining engagement should be a priority.
-- 2. Certain industries, such as Education, Finance, Healthcare, Retail, and Technology, experience higher churn (18% respectively), suggesting potential gaps in product fit or market alignment.
-- 3. Representatives with higher churn rates (David Brown - 5.76%, Henry Moore - 5.74%, Jack Martin - 5.70%) may benefit from additional training or support to address customer challenges effectively.
-- 4. Accounts are more likely to churn compared to opportunities (50.1% Vs. 49.9%, highlighting a need to focus retention strategies on established accounts.

-- TAKEAWAY: RETENTION
-- 1. High product adoption and engagement levels (>=70%) are key indicators of retention, reinforcing the importance of fostering user adoption through education and feature promotion.
-- 2. Non-churned accounts with strong engagement and adoption percentages (>=70%) present significant upsell opportunities to increase revenue.
-- 3. Retained entities often share common attributes such as longer account age (>= Average of 455 Days) and specific plans, indicating these are strong predictors of retention.
-- 4. Retention strategies can be further improved by leveraging insights from high-performing representatives and tailoring outreach for specific verticals (Healthcare, Retail, Technology, & Finance).

---------------------------------------------------------------------------------------------------------------------------------------------------------
