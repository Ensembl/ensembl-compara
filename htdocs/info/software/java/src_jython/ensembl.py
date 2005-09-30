#!/usr/bin/env jython
from __future__ import nested_scopes # compatibility with later versions of Python

"""
==========================================
 Ensembl/Jython: Jython interface to Ensj
==========================================
:Authors: - Michael Hoffman <hoffman@ebi.ac.uk>
          - Craig Melsopp <craig@ebi.ac.uk>
:Organization: EMBL-European Bioinformatics Institute
:Contact: helpdesk@ensembl.org
:Address: Wellcome Trust Genome Campus
          Cambridge
          CB10 1SD
          England
:Date: $Date$
:Revision: $Revision$
:Copyright: 2003-2004 EMBL-European Bioinformatics Institute

Usage
=====
>>> import ensembl
>>> ensembl.fetch("ENSRNOG00000007395").description
'BILE ACID-COENZYME A: AMINO ACID N-ACYLTRANSFERASE; BILE ACID-COENZYME A DEHYDROGENASE: AMINO ACID N-ACYLTRANSFERASE. [Source:RefSeq;Acc:NM_017300]'
>>> ensembl.fetch("ENSMUSG00000029992").displayName
'Gfpt1'
>>> exons = ensembl.fetch("ENSG00000139618").transcripts[0].exons # first transcript
>>> first_five_exons = list(exons)[:5]
>>> [exon.accessionID for exon in first_five_exons]
['ENSE00001184784', 'ENSE00000939159', 'ENSE00000939160', 'ENSE00000939161', 'ENSE00000939162']
>>> print "\n".join([str(exon.location) for exon in first_five_exons])
chromosome_NCBI35:13:31787617-31787804:1
chromosome_NCBI35:13:31788559-31788664:1
chromosome_NCBI35:13:31791214-31791462:1
chromosome_NCBI35:13:31797213-31797321:1
chromosome_NCBI35:13:31798238-31798287:1
>>> print exons[0].sequence.string[:50]
GTGGCGCGAGCTTCTGAAACTAGGCGGCAGAGGCGGAGCCGCTGTGGCAC

Description
===========
Most functionality is provided by Ensj_, so consult the `Ensj
documentation`_ for more information on how to use it. Ensembl/Jython
easy access to Ensj databases and objects through its configuration_
system.

.. _Ensj: http://www.ensembl.org/java/
.. _`Ensj documentation`: http://www.ensembl.org/java/documentation.html
.. _configuration:

Configuration
=============

Zero configuration. Ensembl databases on ensembldb.ensembl.org are
automatically made available via DriverGroupFacades loaded into the
ensembl namespace. For example "ensembl.human" provides access to the
latest human database on the server.

DriverGroups specified in the (optional) user registry file are also
loaded into the ensembl namespace when this module is loaded. See the
org.ensembl.registry.Registry javadocs for more information on adding
databases to this file.

Another way of accessiong an ensembl database is via an explicitly created
driver. For example:
>>> d = CoreDriverFacade({host="SOME_HOST", user="SOME_HOST", database="OLD_HUMAN_DATABSE"})
>>> genes = d.geneAdataptor.fetchIterator(Location("chromosome:22"))

The ensembl.fetch(Ensembl_accession_ID) function uses the
ensembl_prefix associated with each DriverGroup to determine which one
to retrieve genes, exons, transcripts and translations from. By
default if you call ensembl.fetch() with an ID beginning with ENSG,
ENST, ENSP, or ENSE the respective feature is retrieved from the
latest human database on ensembldb.ensembl.org. If you want them to be
retrieved from another database then you need to add another
DriverGroup to your user registry file with ensembl_prefix=ENS.


If you have a problem
=====================

1. Get the newest Ensj snapshot and ensembl.py

2. Complain to helpdesk@ensembl.org if it still doesn't work
   automatically.

"""

__version__ = "$Revision$"

from glob import glob
import os
import re
import sys
import string

import java.lang
import java.util

from org.ensembl import datamodel, driver, util, registry
from org.ensembl.driver.impl import CoreDriverImpl
from org.ensembl.variation.driver.impl import VariationDriverImpl
from org.ensembl.compara.driver.impl import ComparaDriverImpl

# "from ensembl import *" imports only these module attributes:
__all__ = ["CS_CHROMOSOME", "CS_CONTIG", 
           "Location", "CoordinateSystem",
           "AssemblyLocation", "CloneFragmentLocation",
           "DriverFacade",
           "CoreDriver",
           "VariationDriver",
           "ComparaDriver",
           "ensrepr", "ensstr", "fetch", "datamodel", "driver", "util",
           "print_drivers"]


#### Globals

_prefix_2_driver_group_facade = {}
_prefix_2_adaptors = {} 
drivers = {}

#### constant helper functions

def mkdict(**keywds):
    """
    mkdict(**keywds) -> new dictionary initialized with the name=value pairs
    in the keyword argument list. For example: mkdict(one=1, two=2)

    Identical to the Python 2.3 idiom dict(one=1, two=2)
    """
    return keywds

def _within_user_home(pathname):
    """
    more portable than using os.environ["HOME"]
    or os.path.expanduser("~/.ensembl")
    """
    return os.path.join(java.lang.System.getProperty("user.home"), pathname)


#### constants

CONF_SPEC = "*.conf"
STRAND_SYMBOLS = {-1: "<-", 0: "-?-", 1: "->"}
ENSID_INFIXES = mkdict(G="ga", # use abbreviations for _AdaptorFacades, not raw adaptors
                       T="tta",
                       P="tna",
                       E="ea")

ADAPTOR_ABBREVIATIONS = mkdict(
    # core
    aa="analysisAdaptor",
    ca="cloneAdaptor",
    cfa="cloneFragmentAdaptor",
    ea="exonAdaptor",
    fa="featureAdaptor",
    ga="geneAdaptor",
    lc="locationConverterAdaptor",
    ma="markerAdaptor",
    pa="dnaProteinAlignmentAdaptor",
    pta="predictionTranscriptAdaptor",
    ra="repeatFeatureAdaptor",
    sa="sequenceAdaptor",
    siea="stableIdEventAdaptor",
    spa="simplePeptideFeatureAdaptor",
    tna="translationAdaptor",
    tta="transcriptAdaptor",
    vara="variationAdaptor",
    xdba="externalDatabaseAdaptor",
    xra="externalRefAdaptor",
    mfa="miscFeatureAdaptor",
    msa="miscSetAdaptor",
    
    # compara
    ddafa="dnaDnaAlignFeatureAdaptor",
    dfa="dnaFragmentAdaptor",
    gaa="genomicAlignAdaptor",
    gdba="genomeDbAdaptor",
    ha="homologyAdaptor",
    mla="methodLinkAdaptor"
    )

try:
    ENSEMBL_USER_REGISTRY = os.environ["ENSEMBL_USER_REGISTRY"]
except KeyError:
    ENSEMBL_USER_REGISTRY = os.path.join(_within_user_home(".ensembl"),".ensembl_user_registry.ini")

try: # if we are using ensj schema20
    from org.ensembl.datamodel import Location, CoordinateSystem
    
    CS_CHROMOSOME = CoordinateSystem("chromosome")
    CS_CONTIG = CoordinateSystem("contig")

except ImportError: # older schema
    pass

class DriverFacade:
    """
    Abstract Base class which lazy loads a driver defined by a configuration.

    The parameter specifies the database connection parameters.
    These can be supplied as a filename string specifying the path to
    a properties file, a java.utils.Properties instance
    or a python dictionary.
    """
    def __init__(self, configuration):
        import types
        if type(configuration) == types.DictType: # python dictionary
            configuration = dictToProperties(configuration)
        elif type(configuration) == types.StringType: # file
            configuration = util.PropertiesUtil.createProperties(configuration)
        if not isinstance(configuration,java.util.Properties):
            raise Exception("configuration must be a python dictionary or java.util.Properties object.")
        self.configuration = configuration
        self._uninitialized = 1

    def _init_driver(self):
        pass

    def _init(self):
        if self._uninitialized:
            self._init_driver()
            self._uninitialized = 0

    def __getattr__(self, name):
        self._init()
        return getattr(self.driver, name) # if attribute is not on driver, raise AttributeError

    def sql(self, sql, cell_delimiter="\t", outfile=sys.stdout):
        """
        Executes sql query and prints result.
        """
        self._init()        
        conn = self.getConnection()
        stmt = conn.createStatement()
        rs = stmt.executeQuery(sql)
        last_column = rs.metaData.columnCount + 1
        while rs.next():
            print >>outfile, cell_delimiter.join([_get_string(rs, column_index)
                                                  for column_index in xrange(1, last_column)])
        rs.close()
        stmt.close()
        conn.close()

    def __str__(self):
        self._init()        
        return self.driver.toString()

    def __repr__(self):
        self._init()        
        return "<DriverFacade('%s')>" % self.driver


class CoreDriverFacade(DriverFacade):
    def _init_driver(self):
        self.driver = CoreDriverImpl(self.configuration)


class VariationDriverFacade(DriverFacade):
    def _init_driver(self):
        self.driver = VariationDriverImpl(self.configuration)


class ComparaDriverFacade(DriverFacade):
    def _init_driver(self):
        self.driver = ComparaDriverImpl(self.configuration)


class DriverGroupFacade:

    """ Wrapper around DriverGroup instances that provides automatic
    delegation to embedded drivers. """

    def __init__(self, driver_group):
        self.driver_group = driver_group

    def __str__(self):
        return self.driver_group.toString()

    def __repr__(self):
        return "<DriverGroupFacade('%s')>" % self.driver_group

    def __getattr__(self, name):

        """ Delegates to first available instance in the list
        driver_group, coreDriver, variationDriver and comparaDriver.

        Note: it can be much faster to call
        driver_group_facade.driver_group.xxxDriver.yyyAttribute than
        driver_group_facade.yyyAttribute.

        """
        
        if ADAPTOR_ABBREVIATIONS.has_key(name):
            name = ADAPTOR_ABBREVIATIONS[name]
        for obj in [self.driver_group,
                    self.driver_group.coreDriver,
                    self.driver_group.variationDriver,
                    self.driver_group.comparaDriver ]:
            try:
                attr = getattr(obj, name)
                if attr:
                    return attr
            except AttributeError:
                pass
        raise AttributeError 

    def sql(self, sql, cell_delimiter="\t", outfile=sys.stdout):
        """
        Executes sql query against one of the underlying drivers and prints result. Delegates
        to first available driver in list coreDriver, variationDriver and comparaDriver.

        If you want to use a specific driver then you must use it directly e.g. facade.coreDriver.
        """
        conn = self.connection # auto delegate via __getattr__ to appropriatte driver
        stmt = conn.createStatement()
        rs = stmt.executeQuery(sql)
        last_column = rs.metaData.columnCount + 1
        while rs.next():
            print >>outfile, cell_delimiter.join([_get_string(rs, column_index)
                                                  for column_index in xrange(1, last_column)])
        rs.close()
        stmt.close()
        conn.close()


    def all_genes(self,loadChildren=0):
        """Returns an iterator over all genes. Set 'loadChildren=1' if you want
        transcripts, exons and translations to be preloaded which makes accessing them faster."""
        return self.geneAdaptor.fetchIterator(loadChildren)
    
    def all_transcripts(self,loadChildren=0):
        """Returns an iterator over all transcripts. Set 'loadChildren=1' if you want
        exons and translations to be preloaded which makes accessing them faster."""
        return self.transcriptAdaptor.fetchIterator(loadChildren)
    

#### functions

def dictToProperties(dict):
    from java.util import Properties
    p = Properties()
    for key,value in dict.items():
        p.put(key, value)
    return p


def _sorted(seq):
    res = list(seq)
    res.sort()
    return res

def _get_string(result_set, column_index):
    res = result_set.getString(column_index)
    if res is None:
        return "NULL"
    else:
        return res

def _set_property(properties, name, value):
    try:
        properties[name] = value
    except java.lang.NullPointerException:
        pass

def _locrepr(location):
    return "(%s:%s%s%s)" % (location.seqRegionName,
                            location.start,
                            STRAND_SYMBOLS[location.strand],
                            location.end)
    
def ensrepr(feature, delimiter=", ", add_space=0):
    """
    compact representation of common ensembl objects
    """
    return _ensrepr(feature, delimiter, "", delimiter, add_space)

def ensstr(feature, delimiter=None, add_space=0):
    """
    pretty-printed representation of common ensembl objects
    """
    delimiter = "\n" + " " * (add_space+1)
    return _ensrepr(feature, delimiter, delimiter, delimiter, add_space+1, list_str_function=_ensstr_list)

def _ensstr_list(items, delimiter, add_space=0, str_function=ensstr):
    return "%s" % delimiter.join([str_function(item, delimiter, add_space) for item in items])

def _ensrepr_list(items, delimiter, add_space=0):
    return "[%s]" % _ensstr_list(items, delimiter, str_function=ensrepr)

def _ensrepr(feature, sole_delimiter, header_delimiter, body_delimiter, add_space, list_str_function=_ensrepr_list):
    if isinstance(feature, java.util.ArrayList):
        return _ensrepr_list(feature, sole_delimiter) # always call _ensrepr_list and not list_str_function
    if isinstance(feature, datamodel.Location):
        return _locrepr(feature)
    if isinstance(feature, datamodel.Exon):
        return feature.accessionID + _locrepr(feature.location)
    if isinstance(feature, datamodel.Transcript):
        return feature.accessionID + header_delimiter + list_str_function(feature.exons, body_delimiter, add_space)
    if isinstance(feature, datamodel.Gene):
        return feature.accessionID + header_delimiter + list_str_function(feature.transcripts, body_delimiter, add_space=1)
    return feature.accessionID

def _set_ensid_prefix(ensid_prefix, driver_group_facade):
    if ensid_prefix:
        for infix, adaptor_name in ENSID_INFIXES.items():
            _adaptors[ensid_prefix + infix] = getattr(driver_group_facade, adaptor_name)

re_ensid_type = re.compile(r"^\D+") # start-of-line; (any-non-digit-character) one-or-more-times
re_ensid_unversioned = re.compile(r"^([^.]+)") # start-of-line; (any-character-besides-".") one-or-more-times
def fetch(ensid):
    """
    figure out which adaptor to use and fetch from it
    """
    type_prefix = re_ensid_type.match(ensid).group(0)
    try:
        adaptor = _prefix_2_adaptors[type_prefix]
    except KeyError:
        try:
            ensembl_prefix = type_prefix[0:-1] # e.g. ENSG -> ENS
            driver_group_facade = _prefix_2_driver_group_facade[ensembl_prefix]
            adaptor_letter = type_prefix[-1]
            adaptor_type = ENSID_INFIXES.get(adaptor_letter)
            if adaptor_type:
                adaptor = getattr(driver_group_facade, adaptor_type)
                _prefix_2_driver_group_facade[type_prefix] = adaptor
            else:
                return None
            #raise ValueError, "Ensembl ID must start with letter"
        except KeyError, key:
            raise KeyError, "cannot use ensembl.fetch to fetch IDs starting with %s" % key
    ensid_unversioned = re_ensid_unversioned.match(ensid).group(1)
    
    return adaptor.fetch(ensid_unversioned)

def _format_driver_name(driver_name, driver):
    return driver_name

def print_drivers(drivers=drivers):
    """
    print the loaded drivers
    """
    print "\n".join([_format_driver_name(driver_name, driver) for driver_name, driver in _sorted(drivers.items())])

def load_registry(registry):
    for name in registry.groupNames:
        r = DriverGroupFacade(registry.getGroup(name))
        setattr(sys.modules[__name__], name, r) # add facade as an attribute of the current module (ensembl)
        drivers[name]=r
        # Note: use r.driver_group.getXXXCoreConfig() instead of r.getXXXCoreConfig() because (a) it's much faster,
        # and (b) the former prevents reload(ensembl) from working for some reason.
        for conf in [r.driver_group.getCoreConfig(), r.driver_group.getVariationConfig(), r.driver_group.getComparaConfig()]:
            if conf and conf.containsKey("ensembl_prefix"):
                _prefix_2_driver_group_facade[conf.getProperty("ensembl_prefix")] = r
                
def _setup():
    _prefix_2_driver_group_facade.clear()
    _prefix_2_adaptors.clear()
    load_registry(registry.Registry.createDefaultRegistry())

    if registry.Registry.isDefaultUserRegistryAvailable():
        load_registry(registry.Registry.createDefaultUserRegistry())


    ## REMAINING CODE IN FUNCTION TO BE MOVED TO UNIT TEST
        
    ##module = sys.modules[__name__]
    ## print dir(module)
##     print "module.human", module.human
#    print "module.human.geneAdaptor", module.human.geneAdaptor
##     print "module.human.ga", module.human.ga
##     print "module.human.variationAdaptor", module.human.variationAdaptor
##     print "module.compara", module.compara
    #print "show databases", module.compara.sql("show databases")
#    d  = CoreDriverFacade({"database":"mus_musculus_core_32_34", "user":"ensro","port":"23364","host":"127.0.0.1"})
##     print d
##     d = CoreDriverFacade("/home/craig/.ensembl/unit_test_core.properties")
##     print d
    #d = CoreDriverFacade("bob")
    #print d
    #print _prefix_2_driver_group_facade
    
##     print module.fetch("ENSG00000172983")
##     print module.fetch("ENSE00001390003")
##     print module.fetch("ENST00000354715")
##     print module.fetch("ENSZ00001390003")

_setup()
