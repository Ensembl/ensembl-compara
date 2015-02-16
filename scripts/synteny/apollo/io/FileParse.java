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

package apollo.io;

import java.lang.String;
import java.util.StringTokenizer;
import java.util.Vector;
import java.io.File;
import java.io.IOException;
import java.io.DataInputStream;
import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.net.URL;
import java.net.URLConnection;
import java.net.MalformedURLException;



public class FileParse {
  public File inFile;
  public int fileSize;
  int bytes_read = 0;
  public byte[] dataArray;
  public Vector<String> lineArray;
  public int noLines;

  String inType;
  URL url;
  URLConnection urlconn;

  public FileParse() {}
  public FileParse(String fileStr, String type) throws MalformedURLException, IOException {
    this.inType = type;
    //System.err.println("Input type = " + type);
    //System.err.println("Input name = " + fileStr);
    if (type.equals("File")) {
      this.inFile = new File(fileStr);
      this.fileSize = (int)inFile.length();

      //      System.err.println("File: " + inFile);
      //      System.err.println("Bytes: " + fileSize);
    }
    if (type.equals("URL")) {
      url = new URL(fileStr);
      this.fileSize = 0;
      urlconn = url.openConnection();
      //  printinfo(urlconn);
    }

  }
  public void readLines(String inStr) {
    StringTokenizer str = new StringTokenizer(inStr,"\n");
    lineArray = new Vector<String>();
    while (str.hasMoreTokens()) {
      lineArray.addElement(str.nextToken());
    }
    noLines = lineArray.size();
  }
  public void readLines() throws IOException {
    String line;
    this.lineArray = new Vector<String>();
	BufferedReader dataIn;

    if (inType.equals("File")) {
      //Using a bis reduces the file reading time by about a factor of 3
      dataIn = new BufferedReader(new InputStreamReader(new FileInputStream(inFile)));
    } else {
      dataIn = new BufferedReader(new InputStreamReader(urlconn.getInputStream()));
    }
    while ((line = dataIn.readLine()) != null) {
      lineArray.addElement(line);
    }
    noLines = lineArray.size();
  }

  public Vector<String> splitLine(char splitChar, int element) {
    Vector<String> wordVector = new Vector<String>();

    String line = lineArray.elementAt(element);
    char[] charArray = line.toCharArray();

    int i = 0;
    int letter = 0;
    char[] word = new char[line.length()];

    char prev_char = '\n';

    //System.err.println("\nBefore loop");
    //    System.err.println("line " + line + "\nsplitChar :" + splitChar + ":");
    //System.err.println(line.length());

    for (i = 0; i < line.length() ; i++ ) {
      if (charArray[i] != splitChar) {
        word[letter] = charArray[i];
        prev_char = charArray[i];
        letter++;
      } else {
        if ((prev_char != splitChar) && (prev_char != '\n')) {
          wordVector.addElement(new String(word));
          letter = 0;
          word = null;
          word = new char[line.length()];
          prev_char = charArray[i];
          //	  System.err.println("word: " + wordVector.lastElement() + ":");
        }

      }
    }

    //Tack on the last word into the vector - unless we have an empty line
    //or if we have a splitchar at the end of the line

    if (line.length() != 0) {
      if (charArray[line.length() - 1] != splitChar) {
        wordVector.addElement(new String(word));
      }
    } else {
      //returns null vector if empty line
      return(null);
    }

    return(wordVector);
  }





}



