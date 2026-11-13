Welcome to your new dbt project!

### Using the starter project

Try running the following commands:
- dbt run
- dbt test

### Multi-target commands (dev / cm / sk)

This project builds against multiple raw source databases, one dbt target each:

| target | schema  | source database  |
|--------|---------|-------------------|
| dev    | dbt_toko | toko_adb (default) |
| cm     | dbt_cm   | cm_adb            |
| sk     | dbt_sk   | sinar_keramik     |

```bash
# dev (toko) — default target, no --vars needed
uv run dbt build

# cm
uv run dbt seed --target cm
uv run dbt build --target cm --vars '{"source_database": "cm_adb", "item_mapping": "item_mapping_cm", "start_date": "2026-02-08"}'

# sk (sinar_keramik)
uv run dbt seed --target sk
uv run dbt build --target sk --vars '{"source_database": "sinar_keramik", "item_mapping": "item_mapping_sk", "start_date": "2026-02-08"}'
```

`start_date` is optional (omit to not filter). `item_mapping_sk.csv` starts empty — populate it with sinar_keramik's own item_id → nama_barang/description rows as needed.

### Resources:
- Learn more about dbt [in the docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](https://community.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
