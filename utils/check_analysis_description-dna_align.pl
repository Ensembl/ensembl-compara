#!/usr/local/bin/perl

# patch web_data column for dna align features for which we can guess at the type
# run as follows to allow command prompts if you try and change a type
# ( ./check_analysis_description-dna_align.pl > check_analysis_description-dna_align.log_2 )


use FindBin qw($Bin);
use File::Basename qw(dirname);
use Data::Dumper;
use strict;
use warnings;
no warnings 'uninitialized';

BEGIN{
  warn dirname( $Bin );
  unshift @INC, "$Bin/../conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::SpeciesDefs;
use XHTML::Validator;

my $SD = new EnsEMBL::Web::SpeciesDefs;
my $x = XHTML::Validator->new();

my @species = @ARGV ? @ARGV : @{$SD->ENSEMBL_SPECIES};

foreach my $sp ( @species ) {
    print "$sp\n";
    my $tree = $SD->{_storage}{$sp};
    foreach my $db_name ( qw(DATABASE_CORE DATABASE_VEGA DATABASE_OTHERFEATURES DATABASE_CDNA) ) {
	next unless $tree->{'databases'}->{$db_name}{'NAME'};
	print "   $db_name\n";
	my $dbh = db_connect( $tree, $db_name );
	my $dafs = $dbh->selectall_arrayref(
	    'select distinct(a.logic_name)
               from dna_align_feature daf, analysis a
              where daf.analysis_id = a.analysis_id');
#	warn Dumper($dafs);
	my $analyses = $dbh->selectall_hashref(
	    'select a.analysis_id, a.logic_name, ad.display_label,
              ad.displayable, ad.web_data, ad.description, ad.analysis_id as analysis_desc_id
         from analysis as a left join analysis_description as ad on
              a.analysis_id = ad.analysis_id', 'analysis_id'
	  );
	foreach ( keys %$analyses ) {
	    $analyses->{$_}{'description'} =~ s/\s+/ /g; $analyses->{$_}{'description'} =~ s/^ //; $analyses->{$_}{'description'} =~ s/ $//;
	    $analyses->{$_}{'web_data'}    =~ s/\s+/ /g; $analyses->{$_}{'web_data'}    =~ s/^ //; $analyses->{$_}{'web_data'}    =~ s/ $//;
	    $analyses->{$_}{'valid'}       = $x->validate( $analyses->{$_}{'description'} );
	    $analyses->{$_}{'valid'}       =~ s/\s+/ /g; $analyses->{$_}{'valid'}       =~ s/^ //; $analyses->{$_}{'valid'}       =~ s/ $//;
	}
#	warn Dumper($analyses);
#	exit;
	#set web_data if logic_name of dna_align_feature matches cdna|mrna|est
      ID:
	foreach my $id ( keys %$analyses ) {
	    my $ln = $analyses->{$id}{'logic_name'};
	    next ID unless (grep { $_->[0] eq $ln } @{$dafs});
	    my $new_type_value;
	    if ($ln =~ /cdna/i) {
		$new_type_value = 'cdna';
	    }
	    if ($ln =~ /rna/i) {
		$new_type_value = 'rna';
	    }
	    if ($ln =~ /est/i) {
		$new_type_value = 'est';
	    }
	    #hack
	    if ($ln =~ /vertrna/i) {
		$new_type_value = 'cdna';
	    }
	    if ($new_type_value) {
		if (! $analyses->{$id}{'analysis_desc_id'}) {
		    print "     Skipping $sp:$db_name $ln at present since there is no analysis_description entry\n";
		    next ID;
		}
		my $old_values = $analyses->{$id}{'web_data'};

		if (! $old_values) {
		    print "     [$sp:$db_name $ln ] Inserting web_data type of $new_type_value\n";
		    #do the update
		    update_ad( { 'type'=>$new_type_value }, $id, $dbh);
		}
		else {
		    my $obj = eval($old_values);
		    my $old_type_value;
		    if (ref($obj) eq 'HASH') {			
			$old_type_value =  $obj->{'type'};
		    }
		    else {
			$old_type_value =  $old_values;
			$obj = {};
		    }
		    if  ($old_type_value ne $new_type_value ) {
			print STDERR "     [$sp:$db_name logic_name $ln ] Going to change web_data type from $old_type_value to $new_type_value. Proceed [y/N] ? ";
			my $input = lc(<>);
			chomp $input;
			unless ($input eq 'y') {
			    print "     Skipping.\n";
			    next ID;
			}
			print "     [$sp:$db_name logic_name $ln ] Changing web_data type from $old_type_value to $new_type_value\n";
			$obj->{'type'} = $new_type_value;
			#do the update
			update_ad($obj,$id,$dbh);
		    }
		}
	    }
	}		
    }
}

sub update_ad {
    my ($web_data,$id,$dbh) = @_;
    my $s = Dumper($web_data);
    $s =~ s/\$VAR1 =//g;
    $s =~ s/;//g;
    $s =~ s/\n//g;
    $s =~ s/\s//g;
    $s =~ s/\'/\\\'/g;
    my $update_sql = qq(update analysis_description set web_data = \'$s\' where analysis_id = $id);
#    print $update_sql;
    $dbh->do($update_sql);
    return
}

sub db_connect {
  ### Connects to the specified database
  ### Arguments: configuration tree (hash ref), database name (string)
  ### Returns: DBI database handle
  my $tree    = shift @_ || die( "Have no data! Can't continue!" );
  my $db_name = shift @_ || confess( "No database specified! Can't continue!" );

  my $dbname  = $tree->{'databases'}->{$db_name}{'NAME'};
  if($dbname eq '') {
    warn( "No database name supplied for $db_name." );
    return undef;
  }

  #warn "Connecting to $db_name";
  my $dbhost  = $tree->{'databases'}->{$db_name}{'HOST'};
  my $dbport  = $tree->{'databases'}->{$db_name}{'PORT'};
  my $dbuser  = 'ensadmin';#$tree->{'databases'}->{$db_name}{'USER'};
  my $dbpass  = 'ensembl';#$tree->{'databases'}->{$db_name}{'PASS'};
  my $dbdriver= $tree->{'databases'}->{$db_name}{'DRIVER'};
  my ($dsn, $dbh);
  eval {
    if( $dbdriver eq "mysql" ) {
      $dsn = "DBI:$dbdriver:database=$dbname;host=$dbhost;port=$dbport";
      $dbh = DBI->connect(
        $dsn,$dbuser,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } else {
      print STDERR "\t  [WARN] Can't connect using unsupported DBI driver type: $dbdriver\n";
    }
  };

  if( $@ ) {
    print STDERR "\t  [WARN] Can't connect to $db_name\n", "\t  [WARN] $@";
    return undef();
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $db_name database handle undefined\n" );
    return undef();
  }
  return $dbh;
}

