
/*
 * This is a trimmed version of Apollo's module that only supplieds the
 * fields needed by the BuildSynteny program.
 */

package apollo.datamodel;

import java.util.Hashtable;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Vector;
import java.util.Enumeration;

import apollo.util.QuickSort;

public class SeqFeature extends Range {
  
  // -----------------------------------------------------------------------
  // Class/static variables
  // -----------------------------------------------------------------------


  // -----------------------------------------------------------------------
  // Instance variables
  // -----------------------------------------------------------------------

  protected String      id;
  protected String      refId;

  protected SeqFeature refFeature;

  private SeqFeature analogousOppositeStrandFeature=null;

  protected String      biotype = null;

  // Actually keep the default score outside the hash so we don't have to do
  // a hash table lookup every time we want it!!!!
  protected double score;

  protected byte phase = 0;

    /** When translating the offset for the stop codon in genome
      coordinates needs to be adjusted to account for edits to
      the mRNA that alter the relative position of the Stop codon
      on the mRNA vs. the genome (e.g. from translational frame
      shift, or genomic sequencing errors */
    protected int edit_offset_adjust;

    //ADDED by TAIR User object to be used by any data adapter that needs it
  private Object userObject = null;

  private String syntenyLinkInfo = null;

  private SeqFeature cloneSource = null;
  
  public SeqFeature() {
  }

  
  public SeqFeature(int low, int high, String type) {
    init(low,high,type);
  }

  public SeqFeature(int low, int high, String type, int strand) {
    init(low,high,type,strand);
  }

  private void init(int low, int high, String type) {
    setLow  (low);
    setHigh (high);
    setFeatureType (type);
  }

  private void init(int low, int high, String type, int strand) {
    init(low,high,type);
    setStrand(strand);
  }

  /** If biotype is null, returns type */
  public String getTopLevelType() {
    String retType;
      retType = getFeatureType();
    return retType;
  }

  public void setId(String id) {
    this.id = id;
  }
  public String getId() {
    return this.id;
  }

  /** FeatureSet overrides - merge with getNumberOfChildren */
  public int size() { return 0; }

  
  /** By default SeqFeature has no kids so returns -1 be default. */
  public int getFeatureIndex(SeqFeature sf) {
    return -1;
  }
  
  /** no-op. SeqFeatures with children should override(eg FeatureSet). 
      a non child bearing SeqFeature neednt do anything */
  public void addFeature(SeqFeature child) {}
  /** no-op - overridden by FeatureSet */
  public void addFeature(SeqFeature feature, boolean sort){}

  /**
   * The number of descendants (direct and indirect) in this FeatureSet.
   * This method should find each child, and invoke numChildFeatures for each
   * child that is a FeatureSet, and add 1 to the count for all others.
   * FeatureSet implementors should not count themselves, but only the
   * leaf SeqFeature implementations.
   * This should be renamed numDescendants. numChild can lead one to think its
   * its just the kids and not further descendants.
   * In fact there should be 2 methods: numDescendants, numChildren
   *
   * @return the number of features contained anywhere under this FeatureSet
   */
  public int getNumberOfDescendents() {
    return 0;
  }

  private SeqFeature queryFeature;
  /** Query feats hold cigars. This gives hit feats access to query feat & its cigar */
  public void setQueryFeature(SeqFeature queryFeat) {
    this.queryFeature = queryFeat;
  }


  public int        getHstart() { return getStart(); }
  public int        getHend  () { return getEnd(); }
  public int        getHlow() { return getLow(); }
  public int        getHhigh() { return getHigh(); }
  public int        getHstrand() { return getStrand(); }


}
