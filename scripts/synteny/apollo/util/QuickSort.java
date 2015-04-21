
/*
 * This is a trimmed version of Apollo's module that only supplieds the
 * fields needed by the BuildSynteny program.
 */

package apollo.util;


public class QuickSort {

  public static void sort(double[] arr,Object[] s) {
    doubleSort(arr,0,arr.length-1,s);
  }
  public static void sort(double[] arr,Object[] s, int len) {
    doubleSort(arr,0,len-1,s);
  }

  public static void sort(float[] arr,Object[] s) {
    sort(arr,0,arr.length-1,s);
  }

  public static void sort(long[] arr,Object[] s) {
    longSort(arr,0,arr.length-1,s);
  }

  public static void sort(String[] arr,Object[] s) {
    stringSort(arr,0,arr.length-1,s);
  }

  public static void sort(int[] arr,Object[] s) {
    intSort(arr,0,arr.length-1,s);
  }
  public static void reverse(Object[] s) {
    int length = s.length;
    if(length>0) {
       int middle;
       if(length%2 >0)
       	middle = (length-1)/2;
       else 
       	middle = length / 2;
       length--;	
       for(int i=0;i<middle;i++) {
       	 Object tmp = s[i];
	 s[i] = s[length-i];
	 s[length-i] = tmp;
       }
    }
  }

  public static void stringSort(String[] arr,int p, int r,Object[] s) {
    int q;

    if (p < r) {
      q = stringPartition(arr,p,r,s);
      stringSort(arr,p,q,s);
      stringSort(arr,q+1,r,s);
    }
  }

  public static void intSort(int[] arr,int p,int r,Object[] s) {
    int q;
    if (p < r) {
      q = intPartition(arr,p,r,s);
      intSort(arr,p,q,s);
      intSort(arr,q+1,r,s);
    }
  }

  public static void longSort(long[] arr,int p, int r,Object[] s) {
    int q;

    if (p < r) {
      q = longPartition(arr,p,r,s);
      longSort(arr,p,q,s);
      longSort(arr,q+1,r,s);
    }
  }

  public static void sort(float[] arr,int p, int r,Object[] s) {
    int q;

    if (p < r) {
      q = partition(arr,p,r,s);
      sort(arr,p,q,s);
      sort(arr,q+1,r,s);
    }
  }

  public static void doubleSort(double[] arr,int p, int r,Object[] s) {
    int q;

    if (p < r) {
      q = doublePartition(arr,p,r,s);
      doubleSort(arr,p,q,s);
      doubleSort(arr,q+1,r,s);
    }
  }

  private static int doublePartition(double[] arr, int p, int r,Object[] s) {
    double x = arr[p];
    int i = p-1;
    int j = r+1;

    while(true) {
      do {
        j = j-1;
      }	while (arr[j] > x);

      do {
        i = i+1;
      } while (arr[i] < x);

      if ( i < j) {
        double tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;

        Object tmp2 = s[i];
        s[i] = s[j];
        s[j] = tmp2;
      } else {
        return j;
      }
    }
  }

  private static int partition(float[] arr, int p, int r,Object[] s) {
    float x = arr[p];
    int i = p-1;
    int j = r+1;

    while(true) {
      do {
        j = j-1;
      }	while (arr[j] > x);

      do {
        i = i+1;
      } while (arr[i] < x);

      if ( i < j) {
        float tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;

        Object tmp2 = s[i];
        s[i] = s[j];
        s[j] = tmp2;
      } else {
        return j;
      }
    }
  }
  private static int longPartition(long[] arr, int p, int r,Object[] s) {
    float x = arr[p];
    int i = p-1;
    int j = r+1;

    while(true) {
      do {
        j = j-1;
      }	while (arr[j] > x);

      do {
        i = i+1;
      } while (arr[i] < x);

      if ( i < j) {
        long tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;

        Object tmp2 = s[i];
        s[i] = s[j];
        s[j] = tmp2;
      } else {
        return j;
      }
    }
  }
  private static int intPartition(int[] arr, int p, int r,Object[] s) {
    int x = arr[p];
    int i = p-1;
    int j = r+1;

    while(true) {
      do {
        j = j-1;
      }	while (arr[j] > x);

      do {
        i = i+1;
      } while (arr[i] < x);

      if ( i < j) {
        int tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;

        Object tmp2 = s[i];
        s[i] = s[j];
        s[j] = tmp2;
      } else {
        return j;
      }
    }
  }

  private static int stringPartition(String[] arr, int p, int r,Object[] s) {
    String x = arr[p];
    int i = p-1;
    int j = r+1;

    while(true) {
      do {
        j = j-1;
      }	while (arr[j].compareTo(x) < 0);

      do {
        i = i+1;
      } while (arr[i].compareTo(x) > 0);

      if ( i < j) {
        String tmp = arr[i];
        arr[i] = arr[j];
        arr[j] = tmp;

        Object tmp2 = s[i];
        s[i] = s[j];
        s[j] = tmp2;
      } else {
        return j;
      }
    }
  }
}



