
import java.util.*;
import apollo.datamodel.*; //for FeatureSet and FeatureSetI
import apollo.seq.io.*; //for GFFFile
import apollo.util.*; //for QuickSort

public class BuildSynteny {

    public static void main (String[] args) {
	FeatureSet fset = null;
	
        if (args.length < 3 || args.length > 6) {
            System.err.println("Usage: BuildSynteny <gff file> <maxDist> <minSize> [orientFlag]");
            System.err.println("Usage: BuildSynteny <gff file> <maxDist1> <minSize1> <maxDist2> <minSize2> [orientFlag]");
            System.exit(1);
        }

	int maxDist1 = Integer.parseInt(args[1]);
	int minSize1 = Integer.parseInt(args[2]);
	int maxDist2;
	int minSize2;
	int orientFlagIndex = 3;
	if (args.length > 4) {
		maxDist2 = Integer.parseInt(args[3]);
		minSize2 = Integer.parseInt(args[4]);
		orientFlagIndex += 2;
	} else {
		maxDist2 = maxDist1;
		minSize2 = minSize1;
	}
        boolean orientFlag = true;
        if (args.length > orientFlagIndex) {
            if (args[orientFlagIndex].equals("true") || args[orientFlagIndex].equals("1")) {
                orientFlag = true;
            } else if (args[orientFlagIndex].equals("false") || args[orientFlagIndex].equals("0")) {
                orientFlag = false;
            } else {
                System.err.println("Error: arg " + orientFlagIndex + " not a boolean");
                System.err.println("Usage: BuildSynteny <gff file> <maxDist> <minSize> [orientFlag]");
                System.err.println("Usage: BuildSynteny <gff file> <maxDist1> <minSize1> <maxDist2> <minSize2> [orientFlag]");
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
	
	groupLinks(fset, maxDist1, minSize1, maxDist2, minSize2, orientFlag);
	System.exit(0);
    }


    public static FeatureSetI groupLinks (FeatureSetI fset, int maxDist1, int minSize1, int maxDist2, int minSize2, boolean orientFlag) {
	
	FeatureSet newfset = new FeatureSet();

	if ((maxDist1 == 0) || (maxDist2 == 0)) {
	    return fset;
	}

	// First sort the links by start coordinate on the query (main) species
	
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
	
	//=================================================================
	// FIRST LOOP: group links. maxDist is twice original maxDist
	//  feat -> newfset
	//=================================================================

	for (int i= 0; i < feat.length; i++) {
	    
	// System.out.println("Feature is " + feat[i].getName() + " " + feat[i].getLow() + " " + feat[i].getHigh()
	//     + " " + feat[i].getHname() + " " + feat[i].getHlow() + " " + feat[i].getHhigh());
	    if (prev != null) {
		
		// dist1 is the distance between this feature and the previous one on the query (main) species.
		double dist1 = (1.0*Math.abs(feat[i].getLow()  - prev.getLow()));
		// dist2 is the distance between this feature and the previous one on the target (secondary) species.
		double dist2 = (1.0*Math.abs(feat[i].getHlow() - prev.getHlow()));
		
		// System.out.println("Dist is " + feat[i].getHname() + " " +  dist1 + " " + dist2);
		
		// We've reached the end of a block
		if ((dist1 > maxDist1*2) || (dist2 > maxDist2*2) || !feat[i].getHname().equals(prev.getHname())) {
		//if ((dist1 > maxDist*2) || (dist2 > maxDist*2)) {
		    
		    double size1 = Math.abs(maxStart  - minStart);
		    double size2 = Math.abs(maxHStart  - minHStart);
		    
		    // Is the block big enough to keep?
		    if (size1 > minSize1 && size2 > minSize2 && featHolder.size() > 1) {
			
			SeqFeature sf1 = new SeqFeature(minStart,maxStart,prev.getFeatureType());
			SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,prev.getFeatureType());
			
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
	    
	    if (feat[i].getHlow() < minHStart) {
		minHStart = feat[i].getHlow();
	    }
	    
	    if (feat[i].getHigh() > maxStart) {
		maxStart = feat[i].getHigh();
	    }
	    
	    if (feat[i].getHhigh() > maxHStart) {
		maxHStart = feat[i].getHhigh();
	    }
	    
	    // System.out.println("New region bounds " + minStart + " " + maxStart + " " + minHStart + " " + maxHStart);
	    
	    if (prev != null) {
		if ((feat[i].getStart() - prev.getEnd())*(feat[i].getHstart() - prev.getHend()) < 0) {
		    reverseCount++;
		} else {
		    forwardCount++;
		}
	    }
	// System.out.println("minStart = " + minStart + "; minHStart = " + minHStart + "; maxStart = " + maxStart + "; maxHStart " + maxHStart + " fwdCnt = " + forwardCount + " rvsCnt = " + reverseCount);
	    featHolder.addElement(feat[i]);
	    
	    prev = feat[i];
	}
	
	double size1 = Math.abs(maxStart  - minStart);
	double size2 = Math.abs(maxHStart  - minHStart);
	
	if (size1 > minSize1 && size2 > minSize2 && feat.length > 0 && featHolder.size() > 1) {
	    
	    SeqFeature sf1 = new SeqFeature(minStart,maxStart,feat[feat.length-1].getFeatureType());
	    SeqFeature sf2 = new SeqFeature(minHStart,maxHStart,feat[feat.length-1].getFeatureType());
	    
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
	//=================================================================
	// SECOND LOOP: group previous groups. maxDist is 30x the original maxDist
	//  newfset -> tmpfset
	//=================================================================
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
//             System.out.println("Processing feature " + fp.getHname() + " " + 
//                                 fp.getLow() + " " + fp.getHigh() + " - " + 
//                                 fp.getHlow() + " " + fp.getHhigh());
	    
	    if (prev != null) {
		
// 		int internum = find_internum(fp,prev,farr);
		int ori = fp.getHstrand() * prev.getHstrand();
		
		double dist1 = Math.abs(fp.getLow()  - prev.getHigh());
		double dist2 = Math.abs(fp.getHlow() - prev.getHhigh());
		
		if (fp.getHstrand() == -1) {
		    dist2 = Math.abs(fp.getHhigh() - prev.getHlow());
		}
		
		// System.out.println("Distances " + dist1 + " " + dist2 + " " + (Math.abs(dist1 - dist2)));
		// System.out.println("Pog " + internum + " " + ori);
		
		if (! curHname.equals(fp.getHname()) || 
                      dist1 > maxDist1*30 || 
                      dist2 > maxDist2*30 || 
                      find_internum(fp,prev,farr) > 2 || (orientFlag && ori == -1)) { // No ori check in old code
		    
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
	    if (fp.getHlow() < minHStart) {
		minHStart = fp.getHlow();
	    }
	    if (fp.getHigh() > maxStart) {
		maxStart = fp.getHigh();
	    }
	    if (fp.getHhigh() > maxHStart) {
		maxHStart = fp.getHhigh();
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
	    if (Math.abs(fp.getHigh() - fp.getLow()) > minSize1) {
		System.out.println(fp.getName() + "\tcluster\tsimilarity\t" +
				   fp.getLow() + "\t" +
				   fp.getHigh() + "\t100\t" +
				   fp.getStrand() + "\t.\t" +
				   fp.getHname() + "\t" +
				   fp.getHlow() + "\t" +
				   fp.getHhigh());
	    }
	}
	return tmpfset;
    }


    public static int find_internum(FeaturePair f1, FeaturePair prev, FeaturePair[] feat) {
	long start = prev.getHhigh();
	long end   = f1.getHlow();
	
	if (f1.getHlow() < prev.getHhigh()) {
	    start = prev.getHlow();
	    end   = f1.getHhigh();
	}
	
	int count = 0;
	
	//System.out.println("Feature start end " + start + " " + end);
	
	if (f1.getHlow() < prev.getHhigh()) {
	    start = prev.getHlow();
	    end   = f1.getHhigh();
	}
	
	
	
	for (int i = 0; i < feat.length; i++) {
	    FeaturePair fp = feat[i];
	    if (!(feat[i].getHlow() > end || feat[i].getHhigh() < start)) {
		System.out.println(fp.getName() + "\tinternum\tsimilarity\t" +
				   fp.getLow() + "\t" +
				   fp.getHigh() + "\t100\t" +
				   fp.getStrand() + "\t.\t" +
				   fp.getHname() + "\t" +
				   fp.getHlow() + "\t" +
				   fp.getHhigh());
		count++;
	    }
	    if (feat[i].getHlow() > end) {
		return count;
	    }
	}
	
	return count;
    }
}
