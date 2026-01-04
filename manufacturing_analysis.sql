-- ============================================
-- MANUFACTURING QUALITY INTELLIGENCE ANALYSIS
-- Author: Rohit Gill
-- Date: January 2025
-- ============================================

-- ============================================
-- SECTION 1: EXECUTIVE SUMMARY METRICS
-- ============================================

-- Query 1: Overall Summary Dashboard
SELECT 
    COUNT(*) as total_batches,
    SUM(quantity_produced) as total_production,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as overall_defect_rate_pct,
    SUM(defect_cost) as total_defect_cost_inr,
    COUNT(CASE WHEN inspection_result = 'Fail' THEN 1 END) as failed_inspections,
    ROUND(COUNT(CASE WHEN inspection_result = 'Fail' THEN 1 END)::DECIMAL / COUNT(*) * 100, 2) as failure_rate_pct
FROM production_defects;


-- ============================================
-- SECTION 2: SHIFT ANALYSIS
-- ============================================

-- Query 2: Defect Rate by Shift
SELECT 
    shift,
    COUNT(*) as production_batches,
    SUM(quantity_produced) as total_produced,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    SUM(defect_cost) as defect_cost_inr,
    RANK() OVER (ORDER BY SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) DESC) as risk_rank
FROM production_defects
GROUP BY shift
ORDER BY defect_rate_pct DESC;


-- ============================================
-- SECTION 3: PRODUCTION LINE ANALYSIS
-- ============================================

-- Query 3: Production Line Performance
SELECT 
    production_line,
    COUNT(*) as batches,
    SUM(quantity_produced) as total_produced,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    SUM(defect_cost) as defect_cost_inr,
    CASE 
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 3.5 THEN 'NEEDS ATTENTION'
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 2.5 THEN 'MONITOR'
        ELSE 'GOOD'
    END as status
FROM production_defects
GROUP BY production_line
ORDER BY defect_rate_pct DESC;


-- ============================================
-- SECTION 4: DAY OF WEEK ANALYSIS (MONDAY EFFECT)
-- ============================================

-- Query 4: Defect Rate by Day of Week
SELECT 
    day_of_week,
    COUNT(*) as batches,
    SUM(quantity_produced) as total_produced,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    ROUND(
        (SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100) - 
        (SELECT SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 FROM production_defects),
        2
    ) as vs_average_pct
FROM production_defects
GROUP BY day_of_week
ORDER BY 
    CASE day_of_week
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;


-- ============================================
-- SECTION 5: MACHINE PERFORMANCE
-- ============================================

-- Query 5: Machine Performance Ranking
SELECT 
    machine_id,
    COUNT(*) as production_runs,
    SUM(quantity_produced) as total_produced,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    SUM(defect_cost) as defect_cost_inr,
    CASE 
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 4 THEN 'MAINTENANCE REQUIRED'
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 3 THEN 'MONITOR CLOSELY'
        ELSE 'GOOD CONDITION'
    END as machine_status,
    RANK() OVER (ORDER BY SUM(quantity_defective)::DECIMAL / SUM(quantity_produced)) as performance_rank
FROM production_defects
GROUP BY machine_id
ORDER BY defect_rate_pct DESC;


-- ============================================
-- SECTION 6: OPERATOR PERFORMANCE
-- ============================================

-- Query 6: Top and Bottom Performing Operators
WITH operator_stats AS (
    SELECT 
        operator_id,
        COUNT(*) as shifts_worked,
        SUM(quantity_produced) as total_produced,
        SUM(quantity_defective) as total_defects,
        ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
        SUM(defect_cost) as defect_cost_inr
    FROM production_defects
    GROUP BY operator_id
)
SELECT 
    operator_id,
    shifts_worked,
    total_produced,
    total_defects,
    defect_rate_pct,
    defect_cost_inr,
    CASE 
        WHEN defect_rate_pct <= 2.5 THEN 'TOP PERFORMER'
        WHEN defect_rate_pct <= 3.5 THEN 'AVERAGE'
        ELSE 'NEEDS TRAINING'
    END as performance_category,
    RANK() OVER (ORDER BY defect_rate_pct ASC) as rank_best_to_worst
FROM operator_stats
ORDER BY defect_rate_pct ASC;


-- ============================================
-- SECTION 7: DEFECT TYPE ANALYSIS
-- ============================================

-- Query 7: Defect Type Distribution
SELECT 
    defect_type,
    COUNT(*) as occurrences,
    SUM(quantity_defective) as total_defects,
    ROUND(
        SUM(quantity_defective)::DECIMAL / 
        (SELECT SUM(quantity_defective) FROM production_defects WHERE defect_type != 'None') * 100, 
        2
    ) as percentage_of_all_defects
FROM production_defects
WHERE defect_type != 'None'
GROUP BY defect_type
ORDER BY total_defects DESC;


-- ============================================
-- SECTION 8: MONTHLY TREND ANALYSIS
-- ============================================

-- Query 8: Monthly Defect Trend
SELECT 
    month,
    SUM(quantity_produced) as monthly_production,
    SUM(quantity_defective) as monthly_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    SUM(defect_cost) as monthly_defect_cost,
    LAG(ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2)) 
        OVER (ORDER BY MIN(production_date)) as prev_month_rate,
    ROUND(
        SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 -
        LAG(ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2)) 
            OVER (ORDER BY MIN(production_date)),
        2
    ) as month_over_month_change
FROM production_defects
GROUP BY month
ORDER BY MIN(production_date);


-- ============================================
-- SECTION 9: MATERIAL BATCH QUALITY
-- ============================================

-- Query 9: Identify Problem Material Batches
SELECT 
    material_batch,
    COUNT(*) as times_used,
    SUM(quantity_produced) as total_produced,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    CASE 
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 5 THEN 'REJECT - SUPPLIER ISSUE'
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 4 THEN 'QUALITY REVIEW NEEDED'
        ELSE 'ACCEPTABLE'
    END as batch_status
FROM production_defects
GROUP BY material_batch
HAVING COUNT(*) >= 5
ORDER BY defect_rate_pct DESC
LIMIT 15;


-- ============================================
-- SECTION 10: HIGH RISK COMBINATIONS
-- ============================================

-- Query 10: Identify Risky Production Combinations
SELECT 
    production_line,
    shift,
    day_of_week,
    COUNT(*) as occurrences,
    SUM(quantity_defective) as total_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    CASE 
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 5 THEN '🔴 HIGH RISK'
        WHEN SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100 > 3.5 THEN '🟡 MEDIUM RISK'
        ELSE '🟢 LOW RISK'
    END as risk_level
FROM production_defects
GROUP BY production_line, shift, day_of_week
HAVING COUNT(*) >= 3
ORDER BY defect_rate_pct DESC
LIMIT 15;


-- ============================================
-- SECTION 11: COST IMPACT ANALYSIS
-- ============================================

-- Query 11: Cost Impact by Category
SELECT 'Production Line' as category, production_line as subcategory, SUM(defect_cost) as total_cost
FROM production_defects GROUP BY production_line
UNION ALL
SELECT 'Shift' as category, shift as subcategory, SUM(defect_cost) as total_cost
FROM production_defects GROUP BY shift
UNION ALL
SELECT 'Product Type' as category, product_type as subcategory, SUM(defect_cost) as total_cost
FROM production_defects GROUP BY product_type
ORDER BY category, total_cost DESC;


-- ============================================
-- SECTION 12: WEEKLY PERFORMANCE TRACKING
-- ============================================

-- Query 12: Weekly Performance Trend
SELECT 
    week_number,
    COUNT(*) as batches,
    SUM(quantity_produced) as weekly_production,
    SUM(quantity_defective) as weekly_defects,
    ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2) as defect_rate_pct,
    SUM(defect_cost) as weekly_cost,
    ROUND(AVG(ROUND(SUM(quantity_defective)::DECIMAL / SUM(quantity_produced) * 100, 2)) 
        OVER (ORDER BY week_number ROWS BETWEEN 3 PRECEDING AND CURRENT ROW), 2) as four_week_moving_avg
FROM production_defects
GROUP BY week_number
ORDER BY week_number;