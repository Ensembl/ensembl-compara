package EnsEMBL::Web::Factory::Search::AVIndexUtils;

use strict;
use AltaVista::PerlSDK qw(avs_open AVS_OK avs_querymode avs_define_valtype 
                          avs_getindexmode avs_errmsg
                          avs_buildmode avs_startdoc
                          avs_buildmode_ex 
                          avs_setdocdate avs_addword avs_adddate avs_addfield
                          avs_setdocdata avs_enddoc
                          avs_makestable avs_compact avs_compact_minor 
						  avs_compactionneeded
                          avs_create_options
                          avs_create_parameters
                          avs_search
                          avs_getsearchterms
                          avs_getsearchresults
                          avs_search_getdatalen
                          avs_search_getdocid
                          avs_search_getdata
                          avs_search_getdate
                          avs_search_getrelevance
                          avs_search_close
                          avs_search_genrank
                          avs_close
);
use Exporter();
use vars qw(    
	@ISA 
    @EXPORT 
    @EXPORT_OK 
    %EXPORT_TAGS 
    $VERSION
	$DEBUG
);
@EXPORT = qw(
	ens_avs_indexdoc
	ens_avs_commit
	ens_avs_open
	ens_avs_close
	ens_avs_querymode
	ens_avs_buildmode_ex
	ens_avs_version
	ens_avs_getindexversion
	ens_avs_finalize
);

@ISA=qw(Exporter);
$VERSION=1.00;
$DEBUG = 0;

# SUBROUTINES #

#####################################################
## Get version string. Returns array else -1 on error
#####################################################

sub get_date  {

my ($month,$day,$year);
my $now = `date +%m:%d:%y`;
chop($now);

($month,$day,$year) = split(/:/,$now,3);
if ($year > 90){
	$year = "19".$year;
}else{
	$year = "20".$year;
}
if($DEBUG){
	print "Date: $day-$month-$year\n";
}

return ($year,$month,$day);

} # end sub
#####################################################
## Open the index
## Returns index handle or -1 on error
#####################################################

sub ens_avs_indexdoc {

    my ($index_name,$title,$content,$summary,$fieldval) = @_;
    my ($flag,$string);
    my ($date, $status);
    my $startloc = -1;
    my $numwords = -1;
	my ($year,$month,$day) = &get_date();

    $status = avs_startdoc($index_name, $title, 0, $startloc);
    if ($status eq AVS_OK){
        if ($DEBUG){
	    	print "startdoc good\n";
	    	print "start location for next index doc: $startloc\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "Cannot do startdoc ($error)\n";
        return (-1);
    }

    $status = avs_setdocdate ($index_name,$year,$month,$day);
    if ($status eq AVS_OK){
        if($DEBUG){
	    	print "setdocdate good\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "setdocdate failed ($error)\n";
        print STDERR "(Year=$year,Month=$month,Day=$day)\n";
        return (-1);
    }

    ##############################################################
    #index the document contents
    ##############################################################

    $status = avs_addword ($index_name,$content,$startloc,$numwords);
    if ($status eq AVS_OK){
        if($DEBUG){
	    	print "avs_addword good ($numwords words added)\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "avs_addword failed ($error)\n";
        return (-1);
    }

    ##############################################################
    #add the DB identifier
    ##############################################################

    my $fieldloc = ($startloc+$numwords);
    $status = avs_addword ($index_name,$fieldval,$fieldloc,$numwords);
    if ($status eq AVS_OK){
        if($DEBUG){
            print "Field location: $fieldloc\n";
            print "Field value: $fieldval\n";
	    	print "avs_addword for field value good ($numwords words added)\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "avs_addword for field value failed ($error)\n";
        return (-1);
    }

    ##############################################################
    #add field identifier
    ##############################################################

    my $fieldname = "db";
    $status = avs_addfield ($index_name,$fieldname,$fieldloc,($fieldloc+$numwords));
    if ($status eq AVS_OK){
        if($DEBUG){
            my $fieldend = $fieldloc+$numwords;
            print "Field name: $fieldname\n";
	    	print "avs_addfield for field identifier good (locn:$fieldloc-$fieldend)\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "avs_addfield for field identifier failed ($error)\n";
        return (-1);
    }

    $status = avs_setdocdata($index_name,$summary,length($summary));
    if ($status eq AVS_OK){
        if($DEBUG){
	    	print "avs_setdocdata good ($title)\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "setdocdata failed ($error)\n";
        return (-1);
    }

    $status = avs_enddoc($index_name);
    if ($status eq AVS_OK){
        if($DEBUG){
	    	print "avs_enddoc good\n";
        }
    }
    else{
        my $error = avs_errmsg($status);
        print STDERR "enddoc failed ($error)\n";
        return (-1);
    }

    return (1); # add_doc succeeded

} # end of sub

#####################################################
## Commit and minor compact index
## Returns 1 or -1 on error
#####################################################

sub ens_avs_commit {

	my ($index_name) = @_;
	my $done = -1;
	my $needs_compaction = -1;

	my $status = avs_makestable($index_name);
	if ($status eq AVS_OK){
    	if($DEBUG){
		print "makestable good\n";
    	}
	}
	else{
    	my $error = avs_errmsg($status);
    	print STDERR "makestable failed ($error)\n";
    	return (-1);
	}
	$needs_compaction = avs_compactionneeded($index_name);
	if ($needs_compaction == 0) {
    	return (1);
	}
	else {
    	$status = avs_compact_minor($index_name,$done);
    	while ($done){
			$status = avs_compact_minor($index_name,$done);
    	}
    	if ($status eq AVS_OK){
        	if($DEBUG){
	    	print "compacted index\n";
        	}
    	}
    	else{
        	my $error = avs_errmsg($status);
        	print STDERR "compaction failed ($error)\n";
        	return (-1);
    	}
	}
	return (1); # commit succeeded

} # end of sub

#####################################################
## Open the index
## Returns index handle or -1 on error
#####################################################

sub ens_avs_open {

	my ($index_name, $key, $mode) = @_;
	my $status = "";
	my $avs_idx = "";
	#my $interface = "AVS SDK 00.10.3";
	my $interface = "AVS SDK 98.7.28";
	my $ignored_threshold = 1000;
	my $chars_before_wildcard = 3;
	my $unlimited_wild_words = 1;
	my $index_format = -1;
	my $cache_threshold = 500000;
	my $options = 7;
	my $charset = 0;
	my $ntiers = 12;
	my $nbuckets = 12;
	my $READ_WRITE = "rw";
	my $READ_ONLY = "r";
	my $MODE = undef;
	
	if ($mode){
		$MODE = $mode;
	}else{
		$MODE = $READ_ONLY;
	}
	my $parameters = avs_create_parameters($interface,$key,$ignored_threshold,
		$chars_before_wildcard,$unlimited_wild_words,$index_format,
		$cache_threshold,$options,$charset,$ntiers,$nbuckets);

	$status = avs_open($parameters, $index_name, $MODE, $avs_idx);

	if ($status eq AVS_OK){
    	if ($DEBUG){
		print "Index opened\n";
    	}
    	return ($avs_idx);
	}
	else{
    	my $error = avs_errmsg($status);
    	print STDERR "Cannot open index ($error)\n";
    	return (-1);
	}

} # end of sub

#####################################################
## Close the index. Returns 1 else -1 on error
#####################################################
sub ens_avs_close {

	my ($index) = @_;
	my $status = "";

	$status = avs_close($index);

	if ($status eq AVS_OK){
    	if ($DEBUG){
		print "Index closed\n";
    	}
    	return (1);
	}
	else{
    	my $error = avs_errmsg($status);
    	print STDERR "Cannot close index ($error)\n";
    	return (-1);
	}

} # end of sub

#####################################################
## Set query mode. Returns 1 else -1 on error
#####################################################
sub ens_avs_querymode {

	my ($index) = @_;
	my $status = "";

	$status = avs_querymode($index);

	if ($status eq AVS_OK){
    	if ($DEBUG){
			print "Changed to query mode.\n";
    	}
    	return (1);
	}
	else{
    	my $error = avs_errmsg($status);
    	print STDERR "Cannot change to query mode ($error)\n";
    	return (-1);
	}

} # end of sub


#####################################################
## Set build mode. Returns 1 else -1 on error
#####################################################
sub ens_avs_buildmode_ex {

	my ($index, $tiers) = @_;
	my $status = "";

	$status = avs_buildmode_ex($index, $tiers);

	if ($status eq AVS_OK){
        if ($DEBUG){
                print "Changed to build mode.\n";
        }
        return (1);
	}
	else{
        my $error = avs_errmsg($status);
        print STDERR "Cannot change to build mode ($error)\n";
        return (-1);
	}
} # end of sub

#####################################################
## Get version string. Returns array else -1 on error
#####################################################
sub ens_avs_version {

	my @ver = avs_version();
	my ($version_string, $line);
	my $i =0;

	if (@ver){
    	if ($DEBUG){
    		print "Retrieved version information.\n";
		}
		while ($ver[0][$i]){
			$version_string .= $ver[0][$i]."\n";
			$i++;
    	}
    	return ($version_string);
	}else{
		return (-1);
	}

} # end of sub

#######################################################
## Get version string. Returns array else -1 on error
#####################################################
sub ens_avs_getindexversion {

	my $index_name = @_;

	if($index_name){
		return (avs_getindexversion($index_name));
	} 
	else{
		return (-1);
	}

} # end of sub


#######################################################
## Finalise index. Returns -1 on error
#####################################################
sub ens_avs_finalize {

    my ($index_name)=@_;
    my ($done, $status) = "";

    $status = avs_compact($index_name,$done);
    while ($done){
		$status = avs_compact($index_name,$done);
    }

    if ($status eq AVS_OK){
		if($DEBUG){
	    	print "Finally compacted index\n";
		}
    }
    else{
		my $error = avs_errmsg($status);
		print STDERR "Final compaction failed ($error)\n";
		return (-1);
    }

} # end of sub
######################################################

1;


