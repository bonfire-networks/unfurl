ExUnit.start()
# Bypass is only in the build with TEST_WITH_BYPASS, the tests using it are tagged :bypass
if Code.ensure_loaded?(Bypass), do: {:ok, _} = Application.ensure_all_started(:bypass)
{:ok, _} = Application.ensure_all_started(:hackney)
