default['rsynced']['laptops'] = [
  {
    'username': 'dorian',
    'directories': [
      '/home/dorian/Documents',
      '/home/dorian/Dropbox',
      '/home/dorian/old',
      '/home/dorian/Pictures',
    ],
    'target': {
      'directory': '/home/dorian/backup/',
      'host': 'raspi',
      'ip': nil,
    },
    'schedule': {
      # This maps to the cron parameters https://docs.chef.io/resource_cron.html
      'time': nil,
      'minute': '*',
      'hour': '*',
      'day': '*',
      'month': '*',
      'weekday': nil,
    }
  },
]
