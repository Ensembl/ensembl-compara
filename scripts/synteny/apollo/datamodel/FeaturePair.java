
/*
 * This is a trimmed version of Apollo's module that only supplieds the
 * fields needed by the BuildSynteny program.
 */

package apollo.datamodel;

import java.util.*;


public class FeaturePair extends SeqFeature {
  /** query feature, do we really need to store query separately, couldnt query
      just be this and just the associated hit would be a separate SeqFeature?
      Thats really the way to go. how hard a change would this be? */
  SeqFeature query; 
  /** hit feature */
  SeqFeature hit;

  /** f1 is query feature, f2 is hit feature */
  public FeaturePair(SeqFeature f1, SeqFeature f2) {
    this.query = f1;
    setHitFeature(f2);
  }
  public void        setQueryFeature(SeqFeature feature) {
    this.query = feature;
  }
  public SeqFeature getQueryFeature() {
    return query;
  }
  public void        setHitFeature(SeqFeature feature) {
    this.hit = feature;
    // needs access to cigar for on-demand parsing with getAlignment()
    hit.setQueryFeature(this);
  }
  public SeqFeature getHitFeature() {
    return hit;
  }
  /** from SeqFeature */
  public boolean hasHitFeature() { return hit != null; }

  public void        setLow(int low) {
    query.setLow(low);
  }
  public int        getLow() {
    return query.getLow();
  }
  public void        setHigh(int high) {
    query.setHigh(high);
  }
  public int        getHigh() {
    return query.getHigh();
  }
  public void        setStart(int start) {
    query.setStart(start);
  }
  public int        getStart() {
    return query.getStart();
  }
  public void        setEnd(int end) {
    query.setEnd(end);
  }
  public int        getEnd() {
    return query.getEnd();
  }
  public void        setStrand(int strand) {
    query.setStrand(strand);
  }
  public int         getStrand() {
    return query.getStrand();
  }

  public void        setName(String name) {
    query.setName(name);
  }

  public String      getName() {
    return query.getName();
  }

  public void        setId(String id) {
    query.setId(id);
  }
  public String      getId() {
    return query.getId();
  }

  public void        setFeatureType(String type) {
    query.setFeatureType(type);
  }
  public String      getTopLevelType() {
    return query.getTopLevelType();
  }
  // setBioType??
  public String      getFeatureType() {
    return query.getFeatureType();
  }

  public String      getHname() {
    return hit.getName();
  }
  public void        setHname(String name) {
    hit.setName(name);
  }
  public int        getHstart() {
    return hit.getStart();
  }
  public void        setHstart(int start) {
    hit.setStart(start);
  }
  public int        getHend() {
    return hit.getEnd();
  }
  public void        setHend(int end) {
    hit.setEnd(end);
  }
  public void        setHlow(int low) {
    hit.setLow(low);
  }
  public int        getHlow() {
    return hit.getLow();
  }
  public void        setHhigh(int high) {
    hit.setHigh(high);
  }
  public int        getHhigh() {
    return hit.getHigh();
  }

  public void        setHstrand(int strand) {
    hit.setStrand(strand);
  }
  public int         getHstrand() {
    return hit.getStrand();
  }

  /** Gets the index into the hit strings explicitAlignment for a genomic position**/
  public int getHitIndex(int genomicPosition) {
    int index = 0;
    if (isForwardStrand()) {
      index = genomicPosition - query.getLow();
    } else {
      index =  query.getHigh() - genomicPosition;
    }
    
    return index;
  }
  
  public int insertionsBefore(int hitIndex, String alignment) {
    
    int count = 0;
    String query = 
      alignment.substring(0, Math.min(alignment.length(), hitIndex+1));
    int index = query.indexOf('-', 0);
    while (index != -1) {
      count++;
      query = alignment.substring(0, Math.min(alignment.length(), hitIndex+count+1));
      index = query.indexOf('-', index+1);
    }
    
    return count;
  }

  public Range getInsertionRange(int hitIndex, String alignment) {
    
    int start = -1;
    int end = -1;
    
    for (int hi = hitIndex; hi >= 0 && alignment.charAt(hi) == '-'; hi--) {
      start = hi;
    }
    
    for(int hi = hitIndex; 
        hi < alignment.length() && alignment.charAt(hi) == '-'; hi++) {
      end = hi;
    }
    
    // end is exclusive to make substr easier to use.
    if (start != -1) {
      end++;
    }
    
    return new Range(start, end); 
  }
  
  /*public static void main(String[] args) {
    SeqFeature sf1 = new SeqFeature(100,200,"pog",1);
    SeqFeature sf2 = new SeqFeature(100,200,"pog",-1);

    sf1.setName("query");
    sf2.setName("hit");

    System.err.println("Features " + sf1);
    System.err.println("Features " + sf2);
    FeaturePair fp = new FeaturePair(sf1,sf2);
    System.err.println("Feature is " + fp);
    System.err.println("Left/right overlaps " + fp.getLeftOverlap(sf1) + " " + fp.getRightOverlap(sf1));
    System.err.println("Overlap " + fp.isExactOverlap(sf1) + " " + fp.isExactOverlap(sf2));

    //fp.invert();
    System.err.println("Feature is " + fp);

    System.err.println("Overlap " + fp.isExactOverlap(sf1) + " " + fp.isExactOverlap(sf2));
  }*/

  private boolean isEmptyOrNull(String s) {
    if (s==null) return true;
    return s.equals("");
  }

  
}
