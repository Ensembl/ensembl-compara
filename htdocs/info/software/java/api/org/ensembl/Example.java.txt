/*
 Copyright (C) 2001 EBI, GRL

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

package org.ensembl;

import java.text.ParseException;
import java.util.Iterator;
import java.util.List;

import org.ensembl.datamodel.CoordinateSystem;
import org.ensembl.datamodel.Exon;
import org.ensembl.datamodel.ExternalDatabase;
import org.ensembl.datamodel.ExternalRef;
import org.ensembl.datamodel.Gene;
import org.ensembl.datamodel.GeneSnapShot;
import org.ensembl.datamodel.KaryotypeBand;
import org.ensembl.datamodel.Location;
import org.ensembl.datamodel.SequenceRegion;
import org.ensembl.datamodel.Transcript;
import org.ensembl.datamodel.TranscriptSnapShot;
import org.ensembl.datamodel.Translation;
import org.ensembl.datamodel.TranslationSnapShot;
import org.ensembl.driver.AdaptorException;
import org.ensembl.driver.ConfigurationException;
import org.ensembl.driver.CoreDriver;
import org.ensembl.driver.ExonAdaptor;
import org.ensembl.driver.GeneAdaptor;
import org.ensembl.driver.StableIDEventAdaptor;
import org.ensembl.registry.Registry;
import org.ensembl.util.SystemUtil;
import org.ensembl.variation.datamodel.VariationFeature;
import org.ensembl.variation.driver.VariationDriver;

/**
 * Example code demonstrating how to retrieve data from ensembl databases
 * using ensj.
 * 
 * The examples below retrieve data from the latest human core and variation databases on 
 * ensembldb.ensembl.org
 * 
 * @author Craig Melsopp
 * @see <a href="Example.java.html">Example.java</a> source <a href="Example.java">(txt)</a>
 * 
 */

public class Example {

  private CoreDriver coreDriver;

  private VariationDriver variationDriver;

  /**
   * Prints some debug information before printing the output from the
   * example methods in this class.
   * 
   * @param args
   *          ignored.
   * @throws AdaptorException
   *           if a problem occurs retrieving data
   * @throws ConfigurationException
   *           if a problem occurs initialising the driver(s)
   * @throws ParseException
   *           if a problem occurs parsing the string used to construct a
   *           location
   */
  public static void main(String[] args) throws ConfigurationException,
      AdaptorException, ParseException {

    // Dumps some key state information about the runtime environment-
    // useful for debugging purposes
    System.out
        .println(" *** RUNTIME CONFIGURATION (useful for debugging) *** ");
    System.out.println(SystemUtil.environmentDump());

    
    
    System.out.println("\n\n\n *** ENSJ TEST OUTPUT *** ");

    Example example = new Example();

    example.displayDriversState();
    System.out.println();

    example.fetchExonByInternalID();
    System.out.println();

    example.countGenesAndExonsInEachLocation();
    System.out.println();

    example.fetchGeneByStableIDAndViewPeptide();
    System.out.println();

    // create coordinate systems for later use when constructing locations
    CoordinateSystem chromosomeCS = new CoordinateSystem("chromosome");
    CoordinateSystem cloneCS = new CoordinateSystem("clone");
    CoordinateSystem contigCS = new CoordinateSystem("contig");

    // create locations that we can use for fetching and converting later
    // Note the 2 different constructors used. The last provides support
    // for simple ways to define location. See the Location documentation
    // for more information.
    Location contigLoc = new Location(contigCS, "AL159978.14.1.206442");
    Location cloneLoc = new Location(cloneCS, "AB000878.1");
    Location chromosomeLoc = new Location("chromosome:22:21m-21.2m");
    
    example.fetchSequenceRegionsSuchAsChromosomeOrContig(chromosomeCS);
    System.out.println();

    example.fetchSequenceRegionsSuchAsChromosomeOrContig(contigCS);
    System.out.println();

    example.fetchGenesByLocation(cloneLoc);
    System.out.println();

    example.fetchGenesByLocation(contigLoc);
    System.out.println();

    example.convertLocationToCoordinateSystemAndGetTheSeqRegionNames(contigLoc,
        chromosomeCS);
    System.out.println();

    example.convertLocationToCoordinateSystemAndGetTheSeqRegionNames(
        chromosomeLoc, contigCS);
    System.out.println();

    example.fetchDeletedGeneFromArchive();
    System.out.println();

    example.fetchKaryotypes(chromosomeCS, "1");
    System.out.println();

    example.showExternalRefsForAGene();
    System.out.println();

    example.fetchGenesByExternalRefs();
    System.out.println();

    example.fetchVariationsOverlapingGenes();
    System.out.println();

    example.fetchVariationsOverlapingLocation();
    System.out.println();

  }

  /**
   * Creates an instance of Example with core and varition drivers configured.
   * 
   * @throws AdaptorException
   */
  public Example() throws AdaptorException {

    // We need core and variation drivers that point to the latest human databases
    // on ensembldb.ensmbl.org. The easiest way to get these is from the default registry.
    // See org.ensembl.registry.Registry for more information.
    Registry dr = Registry.createDefaultRegistry();
    coreDriver = dr.getGroup("human").getCoreDriver();
    variationDriver = dr.getGroup("human").getVariationDriver();
    
    // Another approach is to use custom configuration files which can point to
    // any ensembl databases.
    //coreDriver = CoreDriverFactory.createCoreDriver("resources/data/example_core_database.properties");
    //variationDriver = VariationDriverFactory.createVariationDriver("resources/data/example_variation_database.properties");
    // the variation driver needs a sister core driver to access the core database
    //variationDriver.setCoreDriver(coreDriver);

    
    // A third way is to use the user default registry. See org.ensembl.registry.Registry
    // for more information.
  }

  /**
   * Fetches all the variations that overlap a particular gene.
   * 
   * @throws AdaptorException
   */
  public void fetchVariationsOverlapingGenes() throws AdaptorException {

    // Fetch the variations that overlap with introns and exons of the gene.
    Gene g = coreDriver.getGeneAdaptor().fetch("ENSG00000179902");
    List vfs = variationDriver.getVariationFeatureAdaptor().fetch(
        g.getLocation());
    for (int i = 0; i < vfs.size(); i++) {
      VariationFeature vf = (VariationFeature) vfs.get(i);
      System.out.println("Variation " + vf.getVariationName() + " (" + vf.getLocation()
          + ") overlaps gene "
          + g.getAccessionID());
    }
  }

  /**
   * Fetches all the variations in a specified location from the variation
   * driver.
   * 
   * @throws AdaptorException
   * @throws ParseException
   */
  public void fetchVariationsOverlapingLocation() throws AdaptorException,
      ParseException {

    Location location = new Location("chromosome:20:20m-20.001m");
    // Fetch ALL the variation features in the location.
    List vfs = variationDriver.getVariationFeatureAdaptor().fetch(location);
    for (int i = 0; i < vfs.size(); i++) {
      VariationFeature vf = (VariationFeature) vfs.get(i);
      System.out.println("Variation " + vf.getVariationName() + " (" + vf.getLocation()
          + ") is in location " + location);
    }
  }

  /**
   * Fetch genes corresponding to various external references/identifier such
   * as HUGO ids and Affymetrix probeset names.
   * 
   * @throws AdaptorException
   */
  public void fetchGenesByExternalRefs() throws AdaptorException {

    // 1553569_at is an affymetrix probeset name
    // HAA0 is a HUGO identifier
    String[] xrefs = new String[] { "1553569_at", "HAAO" };
    
    for (int i = 0; i < xrefs.length; i++) {
      List genes = coreDriver.getGeneAdaptor().fetchBySynonym(xrefs[i]);
      for (int j = 0; j < genes.size(); j++) {
        String geneAccession = ((Gene) genes.get(j)).getAccessionID();
        System.out.println(xrefs[i] + " is associated with gene "
            + geneAccession);
      }
    }
  }

  /**
   * Converts location into the target coordinate system and prints the results.
   * 
   * @param sourceLoc
   *          source location to be converted
   * @param targetCS
   *          target coordinate system to convert location into.
   * @throws AdaptorException
   *           if a problem occured during the conversion
   */
  public void convertLocationToCoordinateSystemAndGetTheSeqRegionNames(
      Location sourceLoc, CoordinateSystem targetCS) throws AdaptorException {

    Location targetLoc = coreDriver.getLocationConverter().convert(sourceLoc,
        targetCS);

    System.out.println("Source Location = " + sourceLoc);
    System.out.println("Target Location = " + targetLoc);

    // a sourceLocation might map to several 'parts' of the targetCS. e.g.
    // a chromosome region mapping to various contigs in the contig coordinate system.
    // Multi-part locations are represented as location linked lists where the location
    // is the head of the list.
    for (Location node = targetLoc; node != null; node = node.next())
      System.out.println("Target Location Sequence Region = "
          + node.getSeqRegionName());

  }
  
  /**
   * Fetch an exon by it's internal id and print it.
   * 
   * @throws AdaptorException
   *           if a problem occured during the retrieval
   */
  public void fetchExonByInternalID()
      throws AdaptorException {
    
    int exonInternalID = 5639;
    
    ExonAdaptor exonAdaptor = coreDriver.getExonAdaptor();

    // Fetch an exon based on it's internalID. The same approach can be used
    // for all the adaptors which support fetch( internalID ).
    Exon exon = exonAdaptor.fetch(exonInternalID);

    // All of the org.datamodel.impl classes support java's toString()
    // method. This means that can print them to find out their current
    // state.
    System.out.println("exon with internal id " + exonInternalID + " = " + exon
        );

  }

  /**
   * Create and then return some ensj locations.
   * 
   * @return array of locations that can used in queries.
   */
  public static Location[] createLocations() {

    // Ensj provides support for using genomic locations. These are used to
    // represent the genomic of most of the biological datatypes, via the
    // getLocation() method and in addition can be used to specify database
    // queries.

    // Every location must have a co-ordinate system; this is defined by
    // the CoordinateSystem object passed to the Location on creation.
    Location[] locations = new Location[1];

    // Create an assembly location. Assembly locations represent part of a
    // genome assembly, in this case part of chromosome 12.
    locations[0] = new Location(new CoordinateSystem("chromosome"), "12",
    // chromosome name
        1, // start
        100000, // end
        -1); // strand

    return locations;
  }

  /**
   * Fetch the genes and exons in several locations and print
   * how many there are in each one.
   * 
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void countGenesAndExonsInEachLocation()
      throws AdaptorException {

    Location[] locations = createLocations();
    
    // The easiest way to get a handle on an adaptor is if you already have
    // it's parent driver.
    GeneAdaptor geneAdaptor = coreDriver.getGeneAdaptor();

    // Count the number of genes and exons in each of the locations.
    for (int i = 0; i < locations.length; ++i) {

      System.out.println("Location = " + locations[i]);

      List genes = geneAdaptor.fetch(locations[i]);

      if (genes == null || genes.size() == 0) {
        System.out.println("No Genes found.");
      } else {
        int geneCount = 0;
        int exonCount = 0;
        Iterator iter = genes.iterator();
        while (iter.hasNext()) {
          Gene gene = (Gene) iter.next();
          geneCount++;
          exonCount += gene.getExons().size();
        }

        System.out.println("num genes = " + geneCount);
        System.out.println("num exons = " + exonCount);

      }

      System.out.println(); // blank line to split result sections
    }
  }

  /**
   * Fetch a gene by it's stable ID and then print the peptide corresponding to
   * its first transcript.
   * 
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void fetchGeneByStableIDAndViewPeptide() throws AdaptorException {

    GeneAdaptor geneAdaptor = coreDriver.getGeneAdaptor();

    Gene gene = geneAdaptor.fetch("ENSG00000179902");

    Transcript transcript = (Transcript) gene.getTranscripts().get(0);
    Translation translation = transcript.getTranslation();
    String peptide = translation.getPeptide();

    System.out.println("Peptide for " + translation.getAccessionID() + " : "
        + peptide);

  }

  /**
   * This method illustrates several ways to retrieve genes from a specified
   * location.
   * 
   * With locations containing few genes the memory and speed differences
   * between the methods will be small but for locations containing many genes
   * the difference is potentially huge.
   * 
   * 
   * @param location
   *          location to fetch genes from
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void fetchGenesByLocation(Location location) throws AdaptorException {

    int nExons = 0;
    int nGenes = 0;

    // use the adaptor directly from the driver
    // to load all of the genes into memory in one go.
    // The transcripts, translations and exons are
    // lazy loaded on demand many lazy load requests require
    // a separate database access.
    List genes = coreDriver.getGeneAdaptor().fetch(location);

    // load all of the genes with their child transcripts, translations
    // and exons preloaded. This will often provide faster
    // access to the child data than lazy loading it because
    // it requires fewer database accesses.
    List genesWithChildren = coreDriver.getGeneAdaptor().fetch(location, true);

    // iterating over the genes provides a compromise between
    // loading all of the genes with children (fastest + largest memory usage)
    // and loading the genes one at a time and lazy loading their
    // children (slowest + minumum memory requirement). In this
    // case we also preload the child data. Iterators are fairly
    // eficient in terms of both speed and memory usage and is
    // very useful for large datasets which are too big to fit in
    // memory.
    Iterator geneIterator = coreDriver.getGeneAdaptor().fetchIterator(location,
        true);

    // make sure the exons are loaded and report the numbers
    // of genes and exons loaded. These should be the same for
    // list/iterator.

    nExons = 0;
    nGenes = genes.size();
    for (int i = 0, n = genes.size(); i < n; i++) {
      Gene g = (Gene) genes.get(i);
      nExons += g.getExons().size();
    }
    System.out.println(location.toString() + " has " + nGenes + " genes and "
        + nExons + " exons.");

    nExons = 0;
    nGenes = genesWithChildren.size();
    for (int i = 0, n = genes.size(); i < n; i++) {
      Gene g = (Gene) genes.get(i);
      nExons += g.getExons().size();
    }
    System.out.println(location.toString() + " has " + nGenes + " genes and "
        + nExons + " exons.");

    nGenes = 0;
    nExons = 0;
    while (geneIterator.hasNext()) {
      nGenes++;
      nExons += ((Gene) geneIterator.next()).getExons().size();
    }

    System.out.println(location.toString() + " has " + nGenes + " genes and "
        + nExons + " exons.");
  }

  /**
   * Fetches information about a gene from the archive.
   * 
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void fetchDeletedGeneFromArchive() 
      throws AdaptorException {

    String geneStableID = "ENSG00000178007";
    int geneVersion = 1;
    
    StableIDEventAdaptor adaptor = coreDriver.getStableIDEventAdaptor();

    // Find stableIDs in the current release that relate to the geneStableID
    List relatedIDs = adaptor.fetchCurrent(geneStableID);
    for (Iterator iter = relatedIDs.iterator(); iter.hasNext();) {
      String relatedID = (String) iter.next();
      System.out.println(geneStableID + " is related to " + relatedID
          + " in the current release.");
    }

    // This section requires schema version >= 15 which are currently in
    // development only.

    // Find the snapshot of the Gene's structure when it changed or was deleted.
    GeneSnapShot geneSnapshot = adaptor.fetchGeneSnapShot(geneStableID,
        geneVersion);
    // we already have the ID and version but this shows how to get them from
    // the snapshot
    String gStableID = geneSnapshot.getArchiveStableID().getStableID();
    String gVersion = geneSnapshot.getArchiveStableID().getStableID();

    TranscriptSnapShot[] transcriptSnapShots = geneSnapshot
        .getTranscriptSnapShots();
    for (int i = 0; i < transcriptSnapShots.length; i++) {

      TranscriptSnapShot tSnapShot = transcriptSnapShots[i];
      String tStableID = tSnapShot.getArchiveStableID().getStableID();
      int tVersion = tSnapShot.getArchiveStableID().getVersion();

      TranslationSnapShot tnSnapShot = tSnapShot.getTranslationSnapShot();
      String tnStableID = tnSnapShot.getArchiveStableID().getStableID();
      int tnVersion = tnSnapShot.getArchiveStableID().getVersion();

      System.out.println(gStableID + "." + gVersion + " -> " + tStableID + "."
          + tVersion + " -> " + tnStableID + "." + tnVersion);

      // If there is a peptide associated with the translation print it too.
      String peptide = tnSnapShot.getPeptide();
      if (peptide != null)
        System.out.println("Peptide: " + peptide);
    }

  }

  /**
   * Fetches information about karyotypes (chromosome bands) for the specified
   * chromosome.
   * 
   * @param coordinateSystem
   *          coordinate system containing the chromosomeName
   * @param chromosomeName
   *          name of the chromosome of interest
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void fetchKaryotypes(CoordinateSystem coordinateSystem,
      String chromosomeName) throws AdaptorException {

    List l = coreDriver.getKaryotypeBandAdaptor().fetch(coordinateSystem,
        chromosomeName);

    System.out.println("Chromosome " + chromosomeName + " has " + l.size()
        + " karyotypes.");

    KaryotypeBand kb = (KaryotypeBand) l.get(0);
    Location loc = kb.getLocation();
    int start = loc.getStart();
    int end = loc.getEnd();

    System.out.println("The first karyotype on chromosome " + chromosomeName
        + " is from " + start + "bp to " + end + "bp.");

  }

  /**
   * Fetches information about the sequence regions.
   * 
   * @throws AdaptorException
   *           if problem occurs during retrieval
   */
  public void fetchSequenceRegionsSuchAsChromosomeOrContig(
      CoordinateSystem coordinateSystem) throws AdaptorException {

    // What sequence regions are are available?
    // In the case of the "chromosome" coordinate system these are chromosomes
    SequenceRegion[] seqRegions = coreDriver.getSequenceRegionAdaptor()
        .fetchAllByCoordinateSystem(coordinateSystem);
    System.out.println("There are " + seqRegions.length
        + " sequence regions in the " + coordinateSystem.getName() + "."
        + coordinateSystem.getVersion() + " coordinate system.");

    SequenceRegion sr = seqRegions[0];
    System.out.println(coordinateSystem.getName() + " " + sr.getName()
        + " has length " + sr.getLength());

  }

  /**
   * Fetches a gene from the database and prints a
   * summary of it's external refs if it has any.
   * 
   * @throws AdaptorException
   */
  public void showExternalRefsForAGene()
      throws AdaptorException {
    
    String geneAccession = "ENSG00000169861";
    
    Gene gene = coreDriver.getGeneAdaptor().fetch(geneAccession);
    List xrefs = gene.getExternalRefs();
    if (xrefs.size() == 0) {
      System.out.println("No xrefs for gene" + geneAccession);
    } else {

      for (int i = 0, n = xrefs.size(); i < n; i++) {
        ExternalRef xref = (ExternalRef) xrefs.get(i);
        ExternalDatabase xdb = xref.getExternalDatabase();
        System.out.println(geneAccession + " has xref " + xref.getDisplayID()
            + " in " + xdb.getName() + "." + xdb.getVersion());
      }
    }

  }

  /**
   * Print details about the drivers' configurations.
   * 
   * @throws AdaptorException
   */
  public void displayDriversState() throws AdaptorException {
    System.out.println("Core CoreDriver: " + coreDriver.toString());
    System.out.println("Variation CoreDriver" + variationDriver.toString());
  }

} // Example
