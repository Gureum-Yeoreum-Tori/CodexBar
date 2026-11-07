import importlib.util
from pathlib import Path
import unittest
spec = importlib.util.spec_from_file_location('mac_costs', Path(__file__).resolve().parents[1] / 'mac_costs.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
class ProjectionTests(unittest.TestCase):
    def test_excludes_identity_projects_and_unknown_fields(self):
        row = {'provider': 'codex', 'email': 'private@example.invalid', 'projects': [{'path': '/private'}],
               'daily': [{'date': '2030-01-01', 'totalCost': 4, 'totalTokens': 10, 'chat': 'secret'}]}
        safe = module.project([row], {'preferredCurrencyCode': 'KRW', 'CodexBar.CurrencyExchangeRates': {'KRW': 1400}})[0]
        self.assertNotIn('email', safe)
        self.assertNotIn('projects', safe)
        self.assertNotIn('chat', safe['daily'][0])
        self.assertEqual(safe['exchangeRate'], 1400)
        self.assertEqual(safe['currency'], 'KRW')
    def test_unknown_values_and_missing_rates_do_not_become_zero(self):
        safe = module.project([{'provider': 'codex', 'last30DaysCostUSD': float('nan')}], {'preferredCurrencyCode': 'KRW'})[0]
        self.assertIsNone(safe['last30DaysCostUSD'])
        self.assertEqual(safe['currency'], 'USD')
        self.assertEqual(safe['exchangeRate'], 1)
if __name__ == '__main__': unittest.main()
