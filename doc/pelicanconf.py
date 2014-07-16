#!/usr/bin/env python
# -*- coding: utf-8 -*- #
from __future__ import unicode_literals

AUTHOR = u'Tiliado'
SITENAME = u'Nuvola Player Documentation'
SITEURL = ''

PATH = '.'
PATH_METADATA = r'(?P<type>\w+)/(?P<dirname>.*?)/(?P<basename>.*?).md'

PAGE_PATHS = ['pages']
DISPLAY_PAGES_ON_MENU = False
PAGE_URL = '{dirname}/{basename}.html'
PAGE_SAVE_AS = '{dirname}/{basename}.html'

ARTICLE_PATHS = ['articles']

OUTPUT_PATH = '../build/doc'
CACHE_PATH = OUTPUT_PATH + '.cache'

TIMEZONE = 'UTC'
DEFAULT_DATE_FORMAT = '%Y-%m-%d %H:%M %z'
DEFAULT_LANG = u'en'

FEED_ALL_ATOM = None
CATEGORY_FEED_ATOM = None
TRANSLATION_FEED_ATOM = None

DEFAULT_PAGINATION = 10

TAG_SAVE_AS = ''
CATEGORY_SAVE_AS = ''
ARCHIVES_SAVE_AS = ''
AUTHORS_SAVE_AS = ''
CATEGORIES_SAVE_AS = ''
TAGS_SAVE_AS = ''

RELATIVE_URLS = True


