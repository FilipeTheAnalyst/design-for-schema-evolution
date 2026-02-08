import traceback, sys
from titan.gitops import collect_configs_from_path, merge_configs, collect_vars_from_environment, merge_vars
from titan.operations.blueprint import blueprint_plan

configs = collect_configs_from_path("titan_cli_config.yml")
yaml_config = {}
for config in configs:
    yaml_config = merge_configs(yaml_config, config[1])

cli_config = {}
env_vars = collect_vars_from_environment()
if env_vars:
    cli_config['vars'] = merge_vars(cli_config.get('vars', {}), env_vars)

try:
    plan = blueprint_plan(yaml_config, cli_config)
    print('Plan generated successfully: ', type(plan))
    # print a brief summary
    try:
        print('resources count:', len(plan.resources))
    except Exception:
        pass
except Exception:
    traceback.print_exc()
    sys.exit(1)
