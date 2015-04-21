/* Jalview - a java multiple alignment editor
 * Copyright (C) 1998  Michele Clamp
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

/*
 * This is a trimmed version of Apollo's module that only supplieds the
 * fields needed by the BuildSynteny program.
 */

package apollo.seq.io;

import java.lang.String;
import java.io.IOException;
import java.util.Vector;
import java.util.StringTokenizer;
import apollo.io.FileParse;
import apollo.datamodel.SeqFeature;
import apollo.datamodel.FeaturePair;

public class GFFFile extends FileParse {
  int noSeqs;
  int maxLength = 0;

  public Vector<SeqFeature> seqs;

  long start;
  long end;

  public GFFFile(String inFile, String type) throws IOException {
    //Read in the file first
    super(inFile,type);

    seqs   = new Vector<SeqFeature>();

    //Read lines from file
    System.err.println("Reading Ensembl-style GFF file " + inFile + "....");
    start = System.currentTimeMillis();
    readLines();
    end = System.currentTimeMillis();
    //    System.err.println("done");
    //System.err.println("Total time taken = " + (end-start) + "ms");

    //    System.err.println("Parsing file....");
    start = System.currentTimeMillis();
	parse();
  }

  public void parse() {

	//System.err.println("parse");
    for (int i = 0; i < lineArray.size(); i++) {
      String line = lineArray.elementAt(i);
		//System.err.println("LINE " + line);

      if (line.indexOf("#") == -1 ) {

        // SMJS Added delimiter argument to call. GFF has 8 tab delimited fields.
        //      The last field is a fairly free text format field, which needs
        //      special handling.

        StringTokenizer st = new StringTokenizer(line,"\t");

        if (st.countTokens() >= 8) {
          try {
            String s      = st.nextToken();
            String type   = st.nextToken();
            String prim   = st.nextToken();

            int    qstart = Integer.parseInt(st.nextToken());
            int    qend   = Integer.parseInt(st.nextToken());
            double score  = 0;
            try {
              score  = (Double.valueOf(st.nextToken())).doubleValue();
            } catch (Exception e) {
              System.err.println("Error parsing score : " + e);
            }
            String strand = st.nextToken();
            String frame  = st.nextToken();
            String id     = prim;

            SeqFeature se = new SeqFeature(qstart,qend,id);

            if (strand.equals("-")) {
              se.setStrand(-1);
            } else {
              se.setStrand(1);
            }

            se.setFeatureType(type);
            //se.setScore(score);
            se.setName(s);
            se.setId(s);
            /*if (!(frame.equals("."))) {
              se.setPhase(Integer.parseInt(frame));
            } else {
              // se.setPhase(-1);
            }*/

            if (st.hasMoreTokens() && prim.equals("similarity")) {
              try {
                // SMJS Get remainder of string by setting
                // delimiter to nothing ("")
                String htok   = st.nextToken("");
                // System.err.println("htok = " + htok);
                // SMJS Setup a new tokenizer which doesn't require tabs
                StringTokenizer sth = new StringTokenizer(htok);
  
                String hid    = sth.nextToken();
                int    hstart = Integer.parseInt(sth.nextToken());
                int    hend   = Integer.parseInt(sth.nextToken());
                int hitStrand = 0;
                SeqFeature f2 = null;
                
                if (hstart < hend){
                  hitStrand = 1;
                  f2 = new SeqFeature(hstart, hend, hid, hitStrand);
                }else{
                  hitStrand = -1;
                  f2 = new SeqFeature(hend, hstart, hid, hitStrand);
                }//end if
  
                f2.setName(hid);
                f2.setId(hid);
  
                se.setId(hid);
                FeaturePair fp = new FeaturePair(se,f2);
  
                seqs.addElement(fp);
              } catch (Exception e) {
                System.err.println("Can't add line - " + line + " " + e);
              }
            } else if (st.hasMoreTokens() && prim.equals("exon")) {

              // SMJS Modified for BDGP GFF file (get rest of string
              String hid   = st.nextToken("\t");

              se.setName(hid);
              se.setId(hid);
              // Try Id instead of name
              seqs.addElement(se);
            } else {
              if (!(prim.equals("intron") ||
                    prim.equals("sequence") ||
                    prim.equals("coding_exon"))) {
                seqs.addElement(se);
              }
            }

          } catch (NumberFormatException nfe) {
            System.err.println("NumberFormatException " + nfe);
            System.err.println("ERROR: parsing line " + line);
          }
        }
      }
    }

    noSeqs = seqs.size();

  }

}
