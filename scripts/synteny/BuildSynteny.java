
import java.util.*;
import apollo.datamodel.*; //for FeatureSet and FeatureSetI
import apollo.seq.io.*; //for GFFFile
import apollo.util.*; //for QuickSort

public class BuildSynteny {

    public static void main (String[] args) {
	FeatureSet fset = null;
	
        if (args.length < 3 || args.length > 4) {
            System.err.println("Usage: BuildSynteny <gff file> <maxDist> <minSize> [orientFlag]");
            System.exit(1);
        }

	int maxDist = Integer.parseInt(args[1]);
	int minSize = Integer.parseInt(args[2]);
        boolean orientFlag = true;
        if (args.length == 4) {
            if (args[3].equals("true") || args[3].equals("1")) {
                orientFlag = true;
            } else if (args[3].equals("false") || args[3].equals("0")) {
                orientFlag = false;
            } else {
                System.err.println("Error: arg 3 not a boolean");
                System.exit(1);
            }
        }
	
	try {
	    GFFFile gff = new GFFFile(args[0],"File");
	    
	    fset = new FeatureSet();
	    
	    for (int i = 0; i < gff.seqs.size(); i++) {
		if (gff.seqs.elementAt(i) instanceof FeaturePairI) {
		    fset.addFeature((SeqFeatureI)gff.seqs.elementAt(i));
		}
	    }
	    
	} catch (Exception e) {
	    System.out.println("Exception " + e);
	}
	
	groupLinks(fset,maxDist,minSize,orientFlag);
	System.exit(0);
    }

    public static FeatureSetI groupLinks (FeatureSetI fset, int maxDist, int minSize, boolean orientFlag) {
	
	FeatureSet newfset = new FeatureSet();

	if (maxDist == 0) {
	    return fset;
	}

	// First sort the links by start coordinate
	
	long[] featStart  = new long[fset.size()];
	
	FeaturePair[] feat = new FeaturePair[fset.size()];
	
	for (int i = 0; i < fset.size(); i++) {
	    FeaturePair sf = (FeaturePair)fset.getFeatureAt(i);
	    feat[i] = sf;
	    featStart[i] = sf.getLow();
	}
	
	QuickSort.sort(featStart,feat);
	
	FeaturePair prev = null;
	
	int minStart  = 1000000000;
	int minHStart = 1000000000;
	
	int maxStart  = -1;
	int maxHStart = -1;
	
	long forwardCount = 0;
	long reverseCount = 0;
	
	Vector featHolder = new Vector();
	
	for (int i= 0; i < feat.length; i++) {
	    
	    if (prev != null) {
		
		double dist1 = (1.0*Math.abs(feat[i].getLow()  - prev.getLow()));
		double dist2 = (1.0*Math.abs(feat[i].getHLow() - prev.getHLow()));
		
		// System.out.println("Dist is " + feat[i].getHname() + " " +  dist1 + " " + dist2);
		
		// We've reached the end of a block
		if ((dist1 > maxDist*2) || (dist2 > maxDist*2) || !feat[i].getHname().equals(prev.getHname())) {
		//if ((dist1 > maxDist*2) || (dist2 > maxDist*2)) {
		    
		    double size1 = Math.abs(maxStart  - minStart);
		    double size2 = Math.abs(maxHStart  - minHStart);
		    
		    // Is the block big enough to keep?
		    if (size1 > minSize && size2 > minSize) {
			
			SeqFeature sf1 = new SeqFeature(minStart,maxStart,prev.getType());
			SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,prev.getType());
			
			sf1.setName(prev.getName());
			sf2.setName(prev.getHname());
			
			if (Math.abs(forwardCount-reverseCount) > 5) {
			    if (forwardCount > reverseCount) {
				sf1.setStrand(1);
				sf2.setStrand(1);
			    } else {
				sf1.setStrand(-1);
				sf2.setStrand(-1);
			    }
			    
			} else {
			    sf1.setStrand(prev.getHstrand());
			    sf2.setStrand(prev.getHstrand());
			}
			
			FeaturePair fp = new FeaturePair(sf1,sf2);
			
			newfset.addFeature(fp);
		    }
		    
		    prev = null;
		    
		    minStart  = 1000000000;
		    minHStart = 1000000000;
		    maxStart  = -1;
		    maxHStart = -1;
		    
		    forwardCount = 0;
		    reverseCount = 0;
		    
		    featHolder = new Vector();
		    
		    // System.out.println("Starting new block " + feat[i].getName());
		} else if (!feat[i].getHname().equals(prev.getHname()))  {
                    System.out.println("ERROR: Should have switched from " + prev.getHname() + " to " + feat[i].getHname());
                }
	    }
	    
	    
	    if (feat[i].getLow() < minStart) {
		minStart = feat[i].getLow();
	    }
	    
	    if (feat[i].getHLow() < minHStart) {
		minHStart = feat[i].getHLow();
	    }
	    
	    if (feat[i].getHigh() > maxStart) {
		maxStart = feat[i].getHigh();
	    }
	    
	    if (feat[i].getHHigh() > maxHStart) {
		maxHStart = feat[i].getHHigh();
	    }
	    
	    // System.out.println("New region bounds " + minStart + " " + maxStart + " " + minHStart + " " + maxHStart);
	    
	    if (prev != null) {
		if ((feat[i].getStart() - prev.getEnd())*(feat[i].getHstart() - prev.getHend()) < 0) {
		    reverseCount++;
		} else {
		    forwardCount++;
		}
	    }
	    
	    featHolder.addElement(feat[i]);
	    
	    prev = feat[i];
	}
	
	double size1 = Math.abs(maxStart  - minStart);
	double size2 = Math.abs(maxHStart  - minHStart);
	
	if (size1 > minSize && size2 > minSize && feat.length > 0) {
	    featHolder.addElement(feat[feat.length-1]);
	    
	    SeqFeature sf1 = new SeqFeature(minStart,maxStart,feat[feat.length-1].getType());
	    SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,feat[feat.length-1].getType());
	    
	    sf1.setName(feat[feat.length-1].getName());
	    sf2.setName(feat[feat.length-1].getHname());
	    
	    // System.out.println("ForwardCount = " + forwardCount + " ReverseCount = " + reverseCount);
	    if (forwardCount > 0 || reverseCount > 0) {
		if (forwardCount > reverseCount) {
		    sf1.setStrand(1);
		    sf2.setStrand(1);
		} else {
		    sf1.setStrand(-1);
		    sf2.setStrand(-1);
		}
	    } else {
		sf1.setStrand(feat[feat.length-1].getHstrand());
		sf2.setStrand(feat[feat.length-1].getHstrand());
	    }
	    
	    FeaturePair fp = new FeaturePair(sf1,sf2);
	    newfset.addFeature(fp);
	}
	
	if (newfset.size() == 0) {
	    return newfset;
	}
	// System.out.println("Grouping groups");
	
	FeatureSet tmpfset = new FeatureSet();
	FeaturePair[] farr = new FeaturePair[newfset.size()];
	
	for (int i = 0; i < newfset.size(); i++) {
	    farr[i] = (FeaturePair)newfset.getFeatureAt(i);
	}
	
	minStart  = 1000000000;
	minHStart = 1000000000;
	
	maxStart  = -1;
	maxHStart = -1;
	
	prev = null;
        String curHname = null;
	
	for (int i=0; i < newfset.size(); i++) {
	    FeaturePair fp = (FeaturePair)newfset.getFeatureAt(i);
	    // System.out.println("Processing feature " + fp.getHname() + " " + 
            //                     fp.getLow() + " " + fp.getHigh() + " - " + 
            //                     fp.getHLow() + " " + fp.getHHigh());
	    
	    if (prev != null) {
		
		int internum = find_internum(fp,prev,farr);
		int ori = fp.getHstrand() * prev.getHstrand();
		
		double dist1 = Math.abs(fp.getLow()  - prev.getHigh());
		double dist2 = Math.abs(fp.getHLow() - prev.getHHigh());
		
		if (fp.getHstrand() == -1) {
		    dist2 = Math.abs(fp.getHHigh() - prev.getHLow());
		}
		
		// System.out.println("Distances " + dist1 + " " + dist2 + " " + (Math.abs(dist1 - dist2)));
		// System.out.println("Pog " + internum + " " + ori);
		
		if (! curHname.equals(fp.getHname()) || 
                      dist1 > maxDist*30 || 
                      dist2 > maxDist*30 || 
                      internum > 2 || (orientFlag && ori == -1)) { // No ori check in old code
		    
		    // System.out.println("New block " + Math.abs(dist1 - dist2) + " " + minStart + " " + prev.getHname());
		    
		    SeqFeature sf1 = new SeqFeature(minStart ,maxStart ,"synten");
		    SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,"synten");
		    

		    sf1.setName(prev.getName());
		    sf2.setName(prev.getHname());
		    
		    FeaturePair newfp = new FeaturePair(sf1,sf2);
		    
		    // System.out.println("Setting group strand " + prev.getStrand());
		    
		    newfp.setStrand(prev.getStrand());
		    tmpfset.addFeature(newfp);
		    
		    minStart  = 1000000000;
		    minHStart = 1000000000;
		    
		    maxStart  = -1;
		    maxHStart = -1;
		    
		    prev = null;
		}
	    }
	    if (fp.getLow() < minStart) {
		minStart = fp.getLow();
	    }
	    if (fp.getHLow() < minHStart) {
		minHStart = fp.getHLow();
	    }
	    if (fp.getHigh() > maxStart) {
		maxStart = fp.getHigh();
	    }
	    if (fp.getHHigh() > maxHStart) {
		maxHStart = fp.getHHigh();
	    }
            if (prev == null) {
                curHname = fp.getHname();
            }
	    
	    prev = fp;
	}
	SeqFeature sf1 = new SeqFeature(minStart,maxStart,"synten");
	SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,"synten");
	
	sf1.setName(prev.getName());
	sf2.setName(prev.getHname());
	
	FeaturePair newfp = new FeaturePair(sf1,sf2);
	newfp.setStrand(prev.getStrand());
	tmpfset.addFeature(newfp);
	
	for (int i=0; i < tmpfset.size(); i++) {
	    FeaturePair fp = (FeaturePair)tmpfset.getFeatureAt(i);
	    if (Math.abs(fp.getHigh() - fp.getLow()) > minSize) {
		System.out.println(fp.getName() + "\tcluster\tsimilarity\t" +
				   fp.getLow() + "\t" +
				   fp.getHigh() + "\t100\t" +
				   fp.getStrand() + "\t.\t" +
				   fp.getHname() + "\t" +
				   fp.getHLow() + "\t" +
				   fp.getHHigh());
	    }
	}
	return tmpfset;
    }

    public static int find_internum(FeaturePair f1, FeaturePair prev, FeaturePair[] feat) {
	long start = prev.getHHigh();
	long end   = f1.getHLow();
	
	if (f1.getHLow() < prev.getHHigh()) {
	    start = prev.getHLow();
	    end   = f1.getHHigh();
	}
	
	int count = 0;
	
	//System.out.println("Feature start end " + start + " " + end);
	
	if (f1.getHLow() < prev.getHHigh()) {
	    start = prev.getHLow();
	    end   = f1.getHHigh();
	}
	
	
	
	for (int i = 0; i < feat.length; i++) {
	    FeaturePair fp = feat[i];
	    if (!(feat[i].getHLow() > end || feat[i].getHHigh() < start)) {
		System.out.println(fp.getName() + "\tinternum\tsimilarity\t" +
				   fp.getLow() + "\t" +
				   fp.getHigh() + "\t100\t" +
				   fp.getStrand() + "\t.\t" +
				   fp.getHname() + "\t" +
				   fp.getHLow() + "\t" +
				   fp.getHHigh());
		count++;
	    }
	    if (feat[i].getHLow() > end) {
		return count;
	    }
	}
	
	return count;
    }
}
