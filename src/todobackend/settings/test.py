from .base import *
import os

INSTALLED_APPS += ('django_nose', )
TEST_RUNNER = 'django_nose.NoseTestSuiteRunner'
TEST_OUTPUT_DIR = os.environ.get('TEST_OUTPUT_DIR', '.')
NOSE_ARGS = [
	'--verbosity=2',
	'--nologcapture',
	'--with-coverage',
	'--cover-package=todo',
	'--with-spec',
	'--spec-color',
	'--with-xunit',
	'--xunit-file=%s/unittests.xml' % TEST_OUTPUT_DIR,
	'--cover-xml',
	'--cover-xml-file=%s/coverage.xml' % TEST_OUTPUT_DIR
]
