# Check ARPL Tables on Server

## Quick Check (from Browser)

Go to your server and visit this URL:

```
http://your-server.com/rlmss/mobile/check_arpl_tables.php
```

This will show you:
- Whether each table exists ✓ or ✗
- How many records in each table
- Full data in each table (for debugging)

### Expected Output

If tables exist and are populated, you should see:

```json
{
  "status": "success",
  "all_tables_exist": true,
  "summary": {
    "competency_scales": 5,
    "activities": 22,
    "ratings": 0,
    "setup_complete": true
  },
  "tables": {
    "arpl_competency_scale": {
      "exists": true,
      "records": 5,
      "data": [...]
    },
    "arplappxb_electrician_activities": {
      "exists": true,
      "records": 22,
      "data": [...]
    },
    "arplappxb_activity_ratings": {
      "exists": true,
      "records": 0
    }
  }
}
```

---

## If Tables Don't Exist

If you see `"all_tables_exist": false` or "exists": false, you need to:

1. **Run the SQL setup script:**
   - File: `c:\projects\rlmss\setup_arpl_data.sql`
   - Use phpMyAdmin or MySQL command line to execute it

2. **Then check again:**
   - Refresh: `http://your-server.com/rlmss/mobile/check_arpl_tables.php`
   - Should show tables with data

---

## Files

- **Check Script**: `/mobile/check_arpl_tables.php`
- **Setup Script**: `/setup_arpl_data.sql`
- **API Endpoint**: `/mobile/get_arpl_competency_data.php` (uses these tables)

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| 404 error | Check file is in `/mobile/` folder |
| Connection error | Check database connection in `/connection.php` |
| Empty tables | Run `/setup_arpl_data.sql` to insert data |
| Permission error | Check MySQL user permissions |

---

Visit `check_arpl_tables.php` now to see the current status!
