"""dbt_analytics: build the dbt project, every model its own task, then run snapshots.

    dbt (Cosmos task group: one run task + one test task per model, in dependency order)
      ->  dbt_snapshot

Cosmos reads the dbt project and turns it into Airflow tasks, so a failed model shows up as one red box you can
retry on its own instead of re-running the whole `dbt build`. dbt runs from its own virtualenv (.venv-dbt), which
keeps dbt's and Airflow's dependencies from fighting.
"""
import os
from datetime import datetime, timedelta
from pathlib import Path

from airflow.sdk import dag, task
from cosmos import DbtTaskGroup, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import InvocationMode, TestBehavior

REPO = Path(__file__).resolve().parents[2]
DBT_DIR = REPO
DBT_BIN = REPO / ".venv-dbt" / "bin" / "dbt"


@dag(
    dag_id="dbt_analytics",
    schedule="0 6 * * *",                 # 06:00 UTC daily
    start_date=datetime(2026, 11, 1),
    catchup=False,                         # exercise: what would catchup=True do on first unpause?
    max_active_runs=1,
    default_args={"retries": 1, "retry_delay": timedelta(minutes=2)},
    tags=["lab", "dbt", "snowflake"],
)
def dbt_analytics():

    dbt = DbtTaskGroup(
        group_id="dbt",
        project_config=ProjectConfig(dbt_project_path=DBT_DIR),
        profile_config=ProfileConfig(
            profile_name="lab",
            target_name=os.environ.get("DBT_TARGET", "dev"),
            profiles_yml_filepath=DBT_DIR / "profiles.yml",
        ),
        execution_config=ExecutionConfig(dbt_executable_path=DBT_BIN),
        render_config=RenderConfig(
            dbt_executable_path=DBT_BIN,             # without it Cosmos reads the graph with the first dbt on PATH
            invocation_mode=InvocationMode.SUBPROCESS,  # dbt lives in .venv-dbt, not in Airflow's environment
            test_behavior=TestBehavior.AFTER_EACH,   # each model's tests run right after it
            exclude=["resource_type:snapshot"],
        ),
        operator_args={"install_deps": True},
    )

    @task.bash(cwd=str(DBT_DIR))
    def dbt_snapshot():
        return f"{DBT_BIN} snapshot"

    dbt >> dbt_snapshot()


dbt_analytics()
