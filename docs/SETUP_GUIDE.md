# Snowflake + dbt + Airflow: your setup, step by step

About 45 minutes on your Mac. Every command below was run end to end on 4 Nov 2026 before this was written:
dbt builds 29 nodes (28 pass, 1 deliberate warning), and the Airflow DAG runs all 18 tasks green.

## What is already done for you

- **A Snowflake trial account** (Enterprise edition, AWS London, $400 of credit, ends 4 Dec 2026).
  - Sign-in page: <https://app.snowflake.com>, account identifier **VNYZOPQ-BN11827**,
    or go straight to <https://vnyzopq-bn11827.snowflakecomputing.com>
  - Username **ELENA**, role ACCOUNTADMIN. Your password is in Pippa's WhatsApp.
- **The foundations**, already created in your account. In BigQuery terms:
  - **Warehouses** `TRANSFORM_WH` and `LOADING_WH`: in Snowflake a "warehouse" is not storage, it is the
    computer that runs queries, paid per second while it is on (BigQuery hides this and bills per data scanned).
    X-Small is the smallest, 1 credit an hour; each one switches itself off after 60 s idle and wakes on the
    next query. Two of them so loads and dbt runs never queue behind each other.
  - **Databases** `RAW` and `ANALYTICS`: a database is like a BigQuery project, a schema inside it like a dataset.
    RAW holds source data as delivered; ANALYTICS holds what dbt builds.
  - **Roles** `LOADER` / `TRANSFORMER` / `REPORTER`: permission bundles, like GCP IAM roles. LOADER writes RAW,
    TRANSFORMER (dbt) reads RAW and builds ANALYTICS, REPORTER (a BI tool) only reads ANALYTICS.
  - **Service user** `PIPELINE_SVC`: the robot account dbt and Airflow sign in as, like a GCP service account.
    No password, only a key pair (step 4).
  - **Resource monitor** `TRIAL_GUARD`: a spending cap that warns at 75% and switches the warehouses off at
    40 credits a month, so the trial can't burn out.
  - The exact commands are in `snowflake/00_setup.sql` in the project, with a comment on each. They are the
    basics interviewers ask about ("warehouse vs database?", "how do you stop costs running away?").
- **Practice data**, already loaded into `RAW.SHOP`: a fictional pet-supplement shop (customers, products,
  orders, order lines, subscriptions, ad spend; about 35,000 rows), with realistic mess in it on purpose.
- **The starter project** `data-stack-lab.zip` (in the same Drive folder as this guide): a working dbt project
  on that data, an Airflow DAG that loads and then builds it, VS Code settings, and the porting cheat sheet.

## Step 1. Sign in to Snowflake (5 min)

1. Open <https://vnyzopq-bn11827.snowflakecomputing.com>, sign in as **ELENA**.
   If it asks you to set up multi-factor authentication, do it (Duo Mobile or a passkey both work).
2. Change the password if you want: your initials (bottom left) → Settings → Authentication.
3. **Projects → Workspaces** (or "Worksheets") → new SQL file, and run:
   ```sql
   select current_account(), current_region(), current_role();
   select count(*) from raw.shop.orders;   -- 11019 (more rows than orders: that is one of the exercises)
   ```

## Step 2. Tools on the Mac (10 min)

Open **Terminal**. Paste **one line at a time and press Enter** after each (pasting alone runs nothing).
Wait for your prompt (the line ending in `$` or `%`) to come back before the next one. If a line says
"already installed", that is fine. If you see `>` at the start of the line instead, the command arrived
incomplete and Terminal is waiting for the rest: press **Ctrl+C** and paste it again.

Homebrew (`brew`) is an app store for the Terminal: `brew install <name>` downloads and sets up a tool.
First check whether you have it:

```bash
brew --version
```

If that prints "Homebrew" and a version, skip to the next block. If it says "command not found", install it
(it asks for your Mac password; nothing shows while you type it, that is normal):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then the one tool this project needs, and a check that it worked (it prints `uv` and a version number):

```bash
brew install uv
uv --version
```

`git` comes with the Mac's developer tools, so it is usually there already (`git --version`). If you have no
VS Code yet: `brew install --cask visual-studio-code`.

`uv` installs Python and the packages; it is much faster than pip and handles separate environments cleanly.

## Step 3. Get the project and open it in VS Code (5 min)

1. Download **data-stack-lab.zip** from the Drive folder (it lands in Downloads).
2. In Terminal, paste this and press Enter (it unpacks the project into your home folder and moves you into it):
   ```bash
   cd ~ && unzip ~/Downloads/data-stack-lab.zip && cd ~/data-stack-lab
   ```
   Then this, which opens the project folder in VS Code:
   ```bash
   open -a "Visual Studio Code" .
   ```
3. VS Code asks **"Do you want to install the recommended extensions?"** → **Install**. They are:
   Python, Power User for dbt, Snowflake, YAML, Better Jinja.
4. From now on use VS Code's own terminal: **Terminal → New Terminal** (Ctrl+`).

## Step 4. Your key pair for the pipeline's service user (5 min)

dbt and Airflow sign in as `PIPELINE_SVC` with a key pair, not a password (Snowflake is retiring password-only
sign-in for programs). The private key stays on your Mac; Snowflake only gets the public half.

In Terminal, run these one line at a time, pressing Enter after each. Some print a few lines
(`Generating RSA private key`, `writing RSA key`) and some print nothing: both are fine.

```bash
mkdir -p ~/.ssh/snowflake && cd ~/.ssh/snowflake
```

```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out rsa_key.p8 -nocrypt
```

```bash
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub && chmod 600 rsa_key.p8
```

The next line prints nothing: it puts the three lines of SQL for Snowflake on your clipboard, with your public key
already inside them. Don't copy anything else until you have pasted it.

```bash
printf "use role securityadmin;\nalter user pipeline_svc set rsa_public_key = '%s';\ndesc user pipeline_svc;\n" "$(grep -v -- '-----' rsa_key.pub | tr -d '\n')" | pbcopy
```

In Snowflake: **Projects → Workspaces** → new SQL file, **Cmd+V** to paste, **Cmd+Shift+Enter** to run all three.
The last result lists `RSA_PUBLIC_KEY_FP` with a value starting `SHA256:`. That is your key's fingerprint.

Then go back to the project folder:

```bash
cd ~/data-stack-lab
```

The second slot, `RSA_PUBLIC_KEY_2`, holds Pippa's key, so Pippa can check your exercises against the same
account. Remove it whenever you like: `alter user pipeline_svc unset rsa_public_key_2;`
(Two slots exist so a key can be rotated with no downtime: that is an interview question too.)

## Step 5. Your settings file (2 min)

```bash
cp .env.example .env
```

Open `.env` in VS Code and change `DBT_SCHEMA=dbt_me` to your own name, e.g. `dbt_elena`. That is your personal
sandbox schema: everything you build lands in `ANALYTICS.DBT_ELENA_*`. Leave the rest as it is.
Then, in the terminal:

```bash
source .env
```

Do `source .env` in every new terminal (dbt and Airflow read their settings from it).

## Step 6. Python environments (5 min)

Your models stay pure SQL; these packages are the tools that run them. dbt and Airflow are themselves Python
programs: dbt fills in `{{ ref() }}`, works out the order and sends the SQL to Snowflake, and an Airflow
pipeline (a DAG) is a small Python file. Dataform is the same idea in JavaScript, which Google runs for you
in the BigQuery console; here you run the engine yourself.

Two separate environments, because dbt and Airflow pin different versions of the same libraries:

```bash
uv venv --python 3.12 .venv-dbt
uv pip install --python .venv-dbt/bin/python -r requirements-dbt.txt

uv venv --python 3.12 .venv-airflow
uv pip install --python .venv-airflow/bin/python -r requirements-airflow.txt \
  --constraint https://raw.githubusercontent.com/apache/airflow/constraints-3.3.2/constraints-3.12.txt
```

## Step 7. dbt: connect and build (5 min)

```bash
source .venv-dbt/bin/activate
cd dbt
dbt deps        # installs dbt_utils
dbt debug       # must end with "All checks passed!"
dbt build       # runs models, tests and the snapshot in dependency order
```

You should see **`Done. PASS=28 WARN=1 ERROR=0`**. The one warning is a test that finds orders whose total doesn't
match their lines: that is real in the data and it is exercise 3.2. In Snowflake you now have
`ANALYTICS.DBT_ELENA_STAGING` (views), `DBT_ELENA_MARTS` (tables) and `DBT_ELENA_SNAPSHOTS`.

Then try, in this order: `dbt source freshness`, `dbt docs generate && dbt docs serve` (opens the lineage graph in
your browser; Ctrl+C to stop), and `dbt build -s fct_orders+` (one model and everything downstream of it).

In VS Code, open `dbt/models/marts/fct_orders.sql`: Power User for dbt shows the lineage, and **Cmd+Enter**
runs the model's SQL against Snowflake and shows the result. Its first use may ask which Python to use: pick
`.venv-dbt`.

## Step 8. Airflow: run the pipeline (10 min)

A second terminal (Terminal → New Terminal), from `~/data-stack-lab`:

```bash
source .env
source .venv-airflow/bin/activate        # required: standalone starts its parts by calling "airflow"
python scripts/generate_shop_data.py     # recreates the practice CSVs the DAG's load step reads
airflow standalone
```

When it settles, open <http://127.0.0.1:8080> (type it exactly, with `http://`: Chrome turns `localhost:8080`
into https and shows "can't provide a secure connection", because Airflow here is plain http). User **admin**; the password is printed in that terminal
(search the output for "Password for user 'admin'") and saved in `airflow/simple_auth_manager_passwords.json.generated`.

1. Find **shop_pipeline**. New DAGs start paused: switch it on. Airflow at once starts the most recent 06:00 run
   it "missed" (no need to press Trigger; if you do, that run waits its turn: exercise 4.3).
2. Watch it in the Grid view: `load_raw`, then a run task and a test task per dbt model, then `dbt_snapshot`.
   About 4 minutes.
3. Open `load_raw` → Logs: every file says "0 files processed". The data was already loaded and COPY INTO
   remembers what it loaded. Exercise 1.6 is about exactly that.

Ctrl+C in that terminal stops Airflow.

## Step 9. Optional: Snowflake inside VS Code

Snowflake icon in the left bar → add a connection: account `VNYZOPQ-BN11827`, user `ELENA`, your password.
Then any `.sql` file can be run against Snowflake from VS Code (handy for the SQL drills).

## Step 10. Bring in the old pipeline and port it

1. Put the Dataform repository into `legacy_dataform/source/` (see `legacy_dataform/README.md`). It is git-ignored.
2. Read `docs/DATAFORM_TO_DBT.md`: the framework mapping, the BigQuery → Snowflake dialect differences (checked on
   your account), and a porting order that works.
3. **Source data.** Each Dataform `declaration` is a source. For each, export a sample from BigQuery (Export → CSV, or
   `bq extract` to Cloud Storage for big ones), then load it into a new schema such as `RAW.LEGACY`:
   Snowsight → **Ingestion → Add Data → Load data into a table** for a quick start, or copy the pattern in
   `scripts/load_raw.py` (stage + `COPY INTO` + audit columns) to make loading a repeatable pipeline step.
   It is client data: keep it to a sample, only in this account, and drop the schema when you are done.
4. Port models into `dbt/models/legacy/` layer by layer, `dbt build -s legacy` after each.

## If something goes wrong

| Symptom | Fix |
|---|---|
| `dbt debug`: "JWT token is invalid" | the public key in Snowflake doesn't match `rsa_key.p8`: repeat step 4; check `SNOWFLAKE_PRIVATE_KEY_PATH` in `.env` |
| `Env var required but not provided: 'SNOWFLAKE_ACCOUNT'` | run `source .env` in that terminal |
| Airflow: `No such file or directory: 'airflow'` | `source .venv-airflow/bin/activate` before `airflow standalone` |
| Airflow page doesn't load | wait 30 seconds after starting; port 8080 taken: `AIRFLOW__API__PORT=8081 airflow standalone` |
| Chrome: "This site can't provide a secure connection" | open <http://127.0.0.1:8080>, not `localhost:8080` (Chrome forced https) |
| Airflow page stopped loading later (Mac slept or Terminal closed) | Airflow stopped with it. New Terminal window: `cd ~/data-stack-lab && source .env && source .venv-airflow/bin/activate && airflow standalone` |
| "Warehouse suspended by resource monitor" | 40 credits used this month: `alter resource monitor trial_guard set credit_quota = 80;` as ACCOUNTADMIN |
| `dbt: command not found` | `source .venv-dbt/bin/activate` |

Costs: an X-Small warehouse is 1 credit an hour of actual running and stops after 60 seconds idle; a full
`dbt build` here takes about 6 seconds of warehouse time. The trial ends on 4 Dec 2026 unless a card is added.
