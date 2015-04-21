
/*
 * This is a trimmed version of Apollo's module that only supplieds the
 * fields needed by the BuildSynteny program.
 */

package apollo.datamodel;

public class Range {

  // -----------------------------------------------------------------------
  // Instance variables
  // -----------------------------------------------------------------------

  protected int    low = -1;
  protected int    high = -1;
  protected byte   strand = 0;
  protected String name = null;
  protected String type = null;


  public Range () {}

  /** Range with NO_NAME name */
  public Range(int start, int end) {
    this(null,start,end);
  }

  public Range (String name, int start, int end) {
    setName (name);
    setStrand (start <= end ? 1 : -1);
    setStart(start);
    setEnd(end);
  }

  /** Returns true if same start,end,type and name. This could potentially
      be changed to equals, theres implications there for hashing. A range
      and its clone will be identical barring modifications. */
  public boolean isIdentical(Range range) {
    if (this == range)
      return true;
    // Features have to have same type,range, AND name
    return (range.getFeatureType().equals(getFeatureType()) && sameRange(range) &&
            range.getName().equals(getName()));
  }

  public void setName(String name) {
      this.name = name;
/*    if (name == null) {
      throw new NullPointerException("Range.setName: can't accept feature name of null. " +
                                     "Use Range.NO_NAME instead.");
    } else if (!name.equals(""))
      this.name = name;*/
  }

  public String getName() {
    return name;
  }

  public boolean hasName() {
    return (name != null) && !name.equals("");
  }

  /** getType is not the "visual" type, 
      ie the type one sees in the EvidencePanel.
      getType returns the "logical" type(the type from the data). 
      These are the types in the squiggly brackets in the tiers 
      file that map to the visual type listed before the squigglies. 
      gui.scheme.FeatureProperty maps logical types
      to visual types (convenience function in DetailInfo.getPropertyType) */
  public String getFeatureType() {
    return this.type;
  }

  public void setFeatureType(String type) {
    if(type == null) {
      throw new NullPointerException("Range.setFeatureType: can't accept feature type of null. " +
                                     "Use SeqFeature.NO_TYPE or 'SeqFeature.NO_TYPE' instead.");
    } else if (!type.equals(""))
      this.type = type;
  }

  public boolean hasFeatureType() {
    return ! (getFeatureType() == null);
  }

  /** @return 1 for forward strand, -1 for reverse strand, 0 for strandless */
  public int getStrand() {
    return (int)this.strand;
  }

  /** Convenience method for getStrand() == 1 */
  public boolean isForwardStrand() {
    return getStrand() == 1;
  }

  public void setStrand(int strand) {
    this.strand = (byte)strand;
  }

  public void setStart(int start) {
    // check if strand is proper given start value?
    if (getStrand() == -1) {
      high = start;
    } else {
      low = start;
    }
  }

  public int getStart() {
    return (getStrand() == -1 ? high : low);
  }

  public void setEnd(int end) {
    if (getStrand() == -1) {
      low = end;
    } else {
      high = end;
    }
  }

  public int getEnd() {
    return (getStrand() == -1 ? low : high);
  }

  public int getLow() {
    return this.low;
  }

  public void setLow(int low) {
    // check if low < high - if not switch, and switch strand?
    this.low = low;
  }

  public int getHigh() {
    return this.high;
  }

  public void setHigh(int high) {
    this.high = high;
  }

  public String getStartAsString() {
    return String.valueOf(new Integer(getStart()));
  }

  public String getEndAsString() {
    return String.valueOf(new Integer(getEnd()));
  }

  
  // These are all overlap methods
  public int getLeftOverlap(Range sf) {
    return (getLow() - sf.getLow());
  }

  public int getRightOverlap(Range sf) {
    return (sf.getHigh() - getHigh());
  }

  public boolean     isExactOverlap (Range sf) {
    if (getLeftOverlap(sf)  == 0  &&
        getRightOverlap(sf) == 0 &&
        getStrand()         == sf.getStrand()) {
      return true;
    } else {
      return false;
    }
  }

  public boolean     contains(Range sf) {
    if (overlaps(sf)             &&
        getLeftOverlap(sf)  <= 0 &&
        getRightOverlap(sf) <= 0 &&
        getStrand()       == sf.getStrand()) {
      return true;
    } else {
      return false;
    }
  }

  public boolean     contains(int position) {
    return (position >= getLow() && position <= getHigh());
  }

  public boolean     overlaps(Range sf) {
    return (getLow()    <= sf.getHigh() &&
            getHigh()   >= sf.getLow()  &&
            getStrand() == sf.getStrand());
  }

  /** Return true if start and end are equal */
  public boolean sameRange(Range r) {
    return getStart() == r.getStart() && getEnd() == r.getEnd();
  }

  public int length() {
    return (getHigh() - getLow() + 1);
  }

  /** If SeqFeature is an instanceof FeatureSet and 
      FeatureSet.hasChildFeatures is true then true.
      Basically convenience method that does the awkward instanceof for you. */
  public boolean canHaveChildren() {
    return false;
  }

  /** Return true if range has not been assigned high & low */
  public boolean rangeIsUnassigned() {
    return low == -1 && high == -1;
  }

  public void convertFromBaseOrientedToInterbase() {
    --low;
  }
  public void convertFromInterbaseToBaseOriented() {
    ++low;
  }

  public String toString() {
    return "Range[name=" + name + ",type=" + type + ",low=" + low + ",high=" + high + ",strand=" + strand + "]";
  }
}
