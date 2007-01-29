package EnsEMBL::Web::DASUpload;

=head1 NAME

EnsEMBL::Web::DASUpload.pm

=head1 SYNOPSIS

The DASUpload object handles the upload of user's annotations onto Ensembl website.

=head1 DESCRIPTION

 my $param_name = 'upload_file'; # this is the name you gave to your input element, e.g <input type="file" name="upload_file" />
 my $du  = EnsEMBL::Web::DASUpload->new();
 if (defined (my $err = $du->upload_data($param_name))) {
   error("Upload Failed: $du->error");
 }

 $du->parse();

 my $uploaded_entries = $du->create_dsn($user_email, $user_password); # Create DAS source

or 

 my $uploaded_entries = $du->update_dsn($user_dsn, $user_password, $user_action); # Update DAS source

or 
    my $du  = EnsEMBL::Web::DASUpload->new();
   $du->remove_dsn($user_dataid, $user_password);  # Remove DAS source

  $du->error() # will return last error or undef


=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use warnings;

use CGI qw( :standard);
use Data::Dumper;

use vars qw( @ISA ); 
use EnsEMBL::Web::DataUpload;
@ISA = qw( EnsEMBL::Web::DataUpload );


my ($chr, $gpos, $pos, $span, $step);

# in case of DB problems we don't want users to see all the debug info. 
my $DB_Error = "DAS Database is temporary unavailable. Please try again later. If the problem persists please contact helpdesk.";

# all DAS tables are named as hydrasource_DDDDDDDD, e.g hydrasource_00000001

my $OLD_DSN_PREFIX = 'hydraeuf_'; # Old name prefix for uploaded data sources

my $DSN_PREFIX = 'hydrasource_'; # Name prefix for uploaded data sources

my $MASTER_TABLE = 'journal'; # Table where all sources configuration is stored
my $TABLE_PREFIX = 'source_'; # Name prefix for tables with features
my $GROUPS_PREFIX = 'groups_';# Name prefix for tables with groups

# ProServer ini file section 
#[hydrasource]
# state         = on
# adaptor       = ensembl_upload
# hydra         = dbi
# transport     = dbi
# basename      = source
# dbname        = upload_db
# host          = upload.sanger.ac.uk
# port          = 3306
# username      = upload_user
# password      =


# Sets / returns  DAS source CSS
sub css {
    my $self = shift;
    if (defined(my $value = shift)) {
	$self->{_css} = $value;
    }
    return $self->{_css};
}

# Sets / returns  DAS source DSN 
sub dsn {
    my $self = shift;
    if (defined(my $value = shift)) {
	$self->{_dsn} = $value;
    }
    return $self->{_dsn};
}

# Sets / returns  the mapping type of the uploaded data. 
sub mapping {
    my $self = shift;
    if (defined( my $value = shift)) {
	$self->{_metadata}->{'coordinate_system'} = $value;
    }
    return $self->{_metadata}->{'coordinate_system'};
}

sub metadata {
    my $self = shift;
    my $key = shift;
    if (defined( my $value = shift)) {
	$self->{_metadata}->{$key} = $value;
    }
    return $self->{_metadata}->{$key};
}


# Sets / returns  DAS source domain
sub domain {
    my $self = shift;
    if (defined(my $value = shift)) {
	$value = "http://$value" if ($value !~ m!^\w+://!);
	$value .= '/das' if ($value !~ m!/das$!);
	$self->{_domain} = $value;
    }
    return $self->{_domain};
}

sub features :lvalue { $_[0]->{_FEATURES}; }
sub groups :lvalue { $_[0]->{_GROUPS}; }

# Parsers for the uploaded data. Ensembl Upload Format versions 1 and 2 are supported.

sub parse {
  my $self = shift;

  $self->features = undef;
  $self->groups = undef;

  my @lines = split(/\r|\n/, $self->data);

  if ($lines[0] =~ /euf_version\s+(\d)/) {
    return $self->parse_euf_2(\@lines);
  }

  return $self->parse_euf_1(\@lines);

}

sub parseWiggle {
  my ($self) = @_;

  my @lines = split(/\r|\n/, $self->data);
  my $lnum = scalar(@lines);
  no strict 'refs';
  my $fcount = 0;
  my $lcount = 0;
  my ($fhash);
  my @feature_keys = ('featureid', 'featuretype', 'method', 'segmentid', 'start', 'end', 'strand', 'phase', 'score', 'attributes');

  $gpos = 0;
  my $action;
  sub fixedStep {
    my $line = shift;
    if ($line =~ /^([\d\.]+)$/) {
      $pos += $step;
      $gpos ++;
      return $chr, $pos, $pos+$span-1, $1;
    }
    return undef;
  }
 
  while ($lcount < $lnum) {
    my $line = shift @lines;
    $lcount ++;

# skip the empty lines
    next unless $line;
    next if ($line =~ /^\#|^\[/); 
    next if ($line =~ /^track|^browser/);
    if ($line =~ /^(fixedStep)\s+chrom=(.+)\s+start=(.+)\s+step=(\d+)/) {
#	    warn "$line\n";
      $action = $1;
      $chr = $2;
      $pos = $3;
      $step = $4;
      if ($line =~ /span=(\d+)/) {
        $span = $1;
      } else {
        $span = 1;
      }
      next;
    }

    if (my ($segment, $start, $end, $score) = &{$action}($line)) {
      $segment =~ s/^chr//;
#      warn "$gpos  *  $segment:$start:$end => $score\n";
      $fhash->{$fcount++} = {
	'segmentid' => $segment,
	'start' => $start,
	'end'  => $end,
	'score' => $score,
	'featureid' => $fcount
      };
    } else {
      warn "ERROR : __LINE__ : $line\n";
    }
  }
  $self->features = $fhash;
  return;
}

sub parse_euf_2 {
    my $self = shift;
    my $data = shift;

    my $lnum = scalar(@$data);
    my $lcount = 0;
    my $fcount = 1;
    my $gcount = 1;

    my $fa = 1; # By default we have annotations at the beginning of the file
    my @css = ();
    my @meta = ();

    my ($ghash, $fhash);
    my @feature_keys = ('featureid', 'featuretype', 'method', 'segmentid', 'start', 'end', 'strand', 'phase', 'score', 'attributes');

    my @group_keys = ('groupid', 'attributes');

    while ($lcount < $lnum) {
	my $line = shift @$data;
	$lcount ++;

# skip the empty lines
	next unless $line;

# parse the meta data
	if ($line =~ /^\#\#\s?(.+)\s+(.+)/){
	    $self->metadata($1, $2);
	    next;
	}
     }
    if ($self->metadata('datatype') eq 'wiggle') {
      return $self->parseWiggle();
    }
    while ($lcount < $lnum) {
	my $line = shift @$data;
	$lcount ++;

# skip the empty lines
	next unless $line;
# parse the section headers
	if ($line =~ /\[annotation(s?)\]/) {
	    $fa = 1;
	    next;
	} elsif ($line =~ /\[(\s?)stylesheet(\s?)\]/) {
	    $fa = 2;
	    next;
	} elsif ($line =~ /\[(\s?)groups(\s?)\]/) {
	    $fa = 3;
	    next;
	} elsif ($line =~ /\[(\s?)meta(\s?)\]/) {
	    $fa = 4;
	    next;
	} elsif ($line =~ /\[.+\]/) { # Start of some other section - just ignore it
	    $fa = 0;
	}

	next if (! $fa);

	if ($fa == 2) { # CSS line - just collect them together
	    push @css , $line;
	    next;
	}
	if ($fa == 4) { # meta data line - just collect them together
	    push @meta , $line;
	    next;
	}
	
	my @line_data = split (/\t/, $line);
#	print "$fa : [ @line_data ] <br/ >";


	if ($fa == 1) { # features
	    %{$fhash->{$fcount++}} = map { $_ => shift(@line_data) } @feature_keys;
	} elsif ($fa == 3) { # groups
	    %{$ghash->{$gcount++}} = map { $_ => shift(@line_data) } @group_keys;
	}

    }

    $self->css(join("\n", @css));
    $self->metadata('_XML', join("\n", @meta));
    $self->groups = $ghash;
    $self->features = $fhash;

    return;
}

sub parse_euf_1 {
    my $self = shift;
    my $data = shift;
    my @lines = @$data;

    my @keys = ('groupname', 'featureid', 'featuretype', 'method', 'segmentid', 'start', 'end', 'strand', 'phase', 'score', 'alignment_start', 'alignment_end');
    my $icount = 1;
    my $lcount = 0;
    my $BR = '###';
    my $EUF = qq{(.+)$BR(.)+$BR(.)+$BR(.)+$BR(.+)$BR(\\d+)$BR(\\d+)$BR(.)$BR(\.|0|1|2|3)$BR(.+)};
    my $EUFREF = qq{(.+)$BR(.)+$BR(.)+};

    my $lnum = scalar(@lines);

  my $fa = 1; # By default we have annotations at the beginning of the file

  my @css = ();
  my $fhash;

  while ($lcount < $lnum) {
      my $line = shift @lines;
      $lcount ++;
      if ($line =~ /\[annotation(s?)\]/) {
	  $fa = 1;
	  next;
      } elsif ($line =~ /\[(\s?)stylesheet(\s?)\]/) {
	  $fa = 2;
	  next;
      } elsif ($line =~ /\[.+\]/) { # Start of some other section [ references or assembly ]
	  $fa = 0;
      }

      if ($fa == 2) {
	  push @css , $line;
	  next;
      }

# we ignore references and assembly ( at least for the time being ). according to js5 they were required by LDAS server. Proserver works fine without them.
      next if (! $fa);

#      print "1: $line<br>";
      next if ($line =~ /^\#|^$|^\s+$/);
#      print "2: $line<br>";

# feature type and feature subtype can consist of multiple words - so we preserve single spaces, then split the line by tabs or multiple spaces then bring back the single spaces ..
# we have to do that because sometimes people cut-and-paste the date from the web pages and tabs get subsituted with multiple spaces in the process .. 

      $line =~ s/\t\s*/$BR/g;
      $line =~ s/(\w)(\s)(\w)/$1_$3/g;
      $line =~ s/\s+/$BR/g;
      $line =~ s/$BR$BR/$BR/g;

#      print "3b: $line<br>";
      $line =~ s/_/ /g;
#      print "3c: $line<br>";
      if ($line !~ /$EUF/) {
	  return $self->error("ERROR: Invalid format. Line $lcount");
      }
      
      my @data = split(/$BR/, $line);
      %{$fhash->{$icount++}} = map { $_ => shift(@data) } @keys;

      if (my $gname = $fhash->{($icount-1)}->{groupname}) {
	  if ($gname ne '.') {
	      $fhash->{($icount-1)}->{attributes} = "group=$gname";
	  }
      }
  }

  $self->css(join("\n", @css));
  $self->metadata('coordinate_system', 'ensembl_location');
  $self->features = $fhash;
  return;
}
  

sub create_dsn {
    my $self = shift;
    my ($email, $password) = @_;
    
    delete ($self->{_error});
    
    $self->error($self->_db_connect()) and  return -1;
    $self->error($self->_create_table($email, $password)) and return -2;
    $self->domain($self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER);
    return $self->_save_data();
}

sub _db_connect {
    my $self = shift;

    my $dbname = $self->species_defs->ENSEMBL_DAS_UPLOAD_DB_NAME;
    my $dbhost = $self->species_defs->ENSEMBL_DAS_UPLOAD_DB_HOST;
    my $dbport = $self->species_defs->ENSEMBL_DAS_UPLOAD_DB_PORT;
    my $dbuser = $self->species_defs->ENSEMBL_DAS_UPLOAD_DB_USER;
    my $dbpass = $self->species_defs->ENSEMBL_DAS_UPLOAD_DB_PASS;

    my $dsn = "DBI:mysql:database=$dbname;host=$dbhost;port=$dbport";
    
    my %attr = (
		PrintError => 0,
		RaiseError => 1,
		AutoCommit => 1
		);
    eval {
	$self->{_dbh} = DBI->connect($dsn, $dbuser, $dbpass, \%attr) || return "Database connection failed:".$DBI::errstr;
    };
    
    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    } 
    return undef;
}

# There is a master table journal 
# +-------------+-------------+------+-----+---------+----------------+
# | Field       | Type        | Null | Key | Default | Extra          |
# +-------------+-------------+------+-----+---------+----------------+
# | id          | int(11)     |      | PRI | NULL    | auto_increment |
# | ftype       | varchar(4)  |      |     | EUF     |                |
# | create_date | date        | YES  |     | NULL    |                |
# | access_date | date        | YES  | MUL | NULL    |                |
# | email       | varchar(64) | YES  | MUL | NULL    |                |
# | passw       | varchar(32) | YES  |     | NULL    |                |
# | css         | text        | YES  |     | NULL    |                
# +-------------+-------------+------+-----+---------+----------------+
#
# there we keep records about all datasources. ftype defines the type of the uploaded data. So far only EUF (Ensembl Upload Format) is upported.
# to create a datasourcefrom the uploaded data, first we create an entry in hydra_journal with current data as create_date and access_date set to NULL.
# then we can just look for an entry with the specified email, today's create_date and access_date set to NULL to find the ID of just created entry.
# once we have the ID of the new datasource we create a table FORMAT_XXXXXXXX that will hold the data. the structure of FORMAT_XXXXXXXX tables will vary depending on the format of the uploaded data. In case of the today's only-supported format EUF :
# e.g describe euf_00000001
#+-----------------+-------------+------+-----+---------+----------------+
#| Field           | Type        | Null | Key | Default | Extra          |
#+-----------------+-------------+------+-----+---------+----------------+
#| id              | int(11)     |      | PRI | NULL    | auto_increment |
#| groupname       | varchar(64) | YES  |     | NULL    |                |
#| featureid       | varchar(64) | YES  |     | NULL    |                |
#| featuretype     | varchar(32) | YES  | MUL | NULL    |                |
#| featuresubtype  | varchar(32) | YES  |     | NULL    |                |
#| segmentid       | varchar(64) | YES  | MUL | NULL    |                |
#| start           | int(11)     | YES  |     | NULL    |                |
#| end             | int(11)     | YES  |     | NULL    |                |
#| strand          | char(1)     | YES  |     | NULL    |                |
#| phase           | char(1)     | YES  |     | NULL    |                |
#| score           | float       | YES  |     | NULL    |                |
#| alignment_start | varchar(32) | YES  |     | NULL    |                |
#| alignment_end   | varchar(32) | YES  |     | NULL    |                |
#+-----------------+-------------+------+-----+---------+----------------+

sub _create_table {
    my $self = shift;
    my ($email, $password) = @_;

    my $dsnid;
    my $css = $self->css || '';
    my $meta = $self->metadata('_XML') || '';
    my $assembly = $self->metadata('assembly') || '*';

    my $cs_id = 2;

    if (my $cs = $self->metadata('coordinate_system')) {
	my $sql2 = qq{ select id from coordinate_system where name = '$cs'};
	eval {
	    my $sth = $self->{_dbh}->prepare($sql2);
	    $sth->execute();
	    $cs_id = $sth->fetchrow;
	};
  
	if ($@) {
	    warn("DB ERROR: $@");
	    return $DB_Error;
	}
	if (! defined ($cs_id)) {
	    return "DB WARNING: $cs is not a recognized coordinate system";
	}
    }

    my $sql = qq{insert into journal (create_date, email, passw, css, meta, coord_system, assembly) values (now(), '$email', '$password', '$css', '$meta', $cs_id, \'$assembly\')};

    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }
    
    $sql = qq{SELECT id FROM $MASTER_TABLE WHERE email = '$email' AND access_date IS NULL ORDER BY create_date DESC};
    eval {
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$dsnid = $sth->fetchrow;
    };
  
    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }

    my $table_name = sprintf("${TABLE_PREFIX}%08d", $dsnid);  
    $self->dsn(sprintf("${DSN_PREFIX}%08d", $dsnid));  

    $sql = qq{
CREATE TABLE $table_name (
  id int not null auto_increment,
  featureid varchar(64),
  featuretype varchar(32),
  method varchar(32),
  segmentid varchar(64),
  start int,
  end int,
  strand char,
  phase char,
  score float,
  attributes text,
  primary key(id), index(segmentid), index (featuretype) ) TYPE=MyISAM
};

    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }
   
    $sql = qq{ update journal set access_date = now() where id = $dsnid };
    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }

    my $gtable_name = sprintf("groups_%08d", $dsnid);  
    $sql = qq{
CREATE TABLE $gtable_name (
  id int not null auto_increment,
  groupid varchar(64),
  attributes text,
  primary key(id), index(groupid) ) TYPE=MyISAM
};

    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }

    return undef;
}


# Save the uploaded data into a table. ATM it supports only EUF format hence there is no check on fily_type.
sub _save_data {
  my $self = shift;

  (my $table_name = $self->dsn()) =~ s/$DSN_PREFIX/$TABLE_PREFIX/;

  my $sql = qq{insert into $table_name (featureid, featuretype, method, segmentid, start, end, strand, phase, score, attributes) values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)};
      
  my $icount = 0;
  my $gcount = 0;

  eval {
    my $sth = $self->{_dbh}->prepare($sql);

    foreach (keys (%{$self->features})) {
      my $hashref = $self->features->{$_};
#      warn(Dumper($hashref));
      $sth->execute($hashref->{featureid}, $hashref->{featuretype}, $hashref->{method}, $hashref->{segmentid}, $hashref->{start}, $hashref->{end}, $hashref->{strand}, $hashref->{phase}, $hashref->{score}, $hashref->{attributes});

      $icount ++;
    }
    $sth->finish();
  };

  if ($@) {
      warn("DB ERROR: $@");
      $self->error($DB_Error);
      return -3;
  }

  if ($self->groups) {
      (my $table_name = $self->dsn()) =~ s/$DSN_PREFIX/$GROUPS_PREFIX/;
      my $gsql = qq{insert into $table_name (groupid, attributes) values(?, ?)};
      my $gusql = qq{update $table_name set attributes = ? where groupid = ?};
      eval {
	  my $usth = $self->{_dbh}->prepare($gusql);
	  my $sth = $self->{_dbh}->prepare($gsql);

	  foreach (keys (%{$self->groups})) {
	      my $hashref = $self->groups->{$_};
#	      warn(Dumper($hashref));
	      if (my $c = $usth->execute($hashref->{attributes}, $hashref->{groupid}) < 1) {
		  $sth->execute($hashref->{groupid}, $hashref->{attributes});
	      }

	      $gcount ++;
	  }
	  $sth->finish();
      };

      if ($@) {
	  warn("DB ERROR: $@");
	  $self->error($DB_Error);
	  return -4;
      }

  }
  return ($icount, $gcount);
}  

# When we remove datasource we need to remove the corresponding entry from hydra_journal and drop the corresponding table
sub remove_dsn {
    my $self = shift;
    my ($dsn, $password) = @_;
    
    delete ($self->{_error});

    $self->error($self->_db_connect()) and  return -1;
    
    (my $dsn_id = $dsn) =~ s/^$DSN_PREFIX(0)*//;
    my $jid;
    
    my $sql = qq{select id from $MASTER_TABLE where id = '$dsn_id' and passw = '$password'};
    eval {
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$jid = $sth->fetchrow;
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $self->error($DB_Error);
    }

    if (! defined($jid)) {
	return $self->error("Error: no such data source or invalid password");
    }

    $sql = qq{delete from $MASTER_TABLE where id = $dsn_id and passw = '$password'};
    eval {
	$self->{_dbh}->do($sql);
    };
    
    if ($@) {
	warn("DB ERROR: $@");
	return $self->error($DB_Error);
    }
    
    $sql = qq{ DROP TABLE $dsn};
    
    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $self->error($DB_Error);
    }
   
    return undef;
}

# When 'overwrite' is passed as $action the data in the table are overwritten, otherwise just added to the existing.
sub update_dsn {
    my $self = shift;
    my ($dsn, $password, $action) = @_;

    delete ($self->{_error});
    
    if ($dsn =~ /^hydraeuf_/) {
	return $self->_update_oldsource(@_);
    }

    $self->error($self->_db_connect()) and  return -1;
    (my $dsnid = $dsn) =~ s/^$DSN_PREFIX(0)*//;
    
    my $sql = qq{select id from $MASTER_TABLE where id = '$dsnid' and passw = '$password'};
    my $jid;
    my $sth;
    eval {
	$sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$jid = $sth->fetchrow;
    };

    if ($@) {
	warn("DB Error: $@");
	$self->error($DB_Error) and return -2;
    }
    $sth->finish;

    if (! defined($jid)) {
	$self->error("Error: no such data source or invalid password");
	return -3;
    }

    $self->dsn($dsn);
    
    if ($action eq 'overwrite') {
	(my $tname = $dsn) =~ s/$DSN_PREFIX/$TABLE_PREFIX/;
	$sql = qq{truncate $tname};
	eval {
	    $self->{_dbh}->do($sql);
	};

	if ($@) {
	    warn("DB Error: $@");
	    $self->error($DB_Error) and return -4;
	}

	(my $gname = $dsn) =~ s/$DSN_PREFIX/$GROUPS_PREFIX/;
	$sql = qq{truncate $gname};
	eval {
	    $self->{_dbh}->do($sql);
	};

	if ($@) {
	    my $gtable_name = sprintf("$GROUPS_PREFIX%08d", $dsnid);  
	    $sql = qq{
CREATE TABLE $gtable_name (
  id int not null auto_increment,
  groupid varchar(64),
  attributes text,
  primary key(id), index(groupid) ) TYPE=MyISAM
};

	    eval {
		$self->{_dbh}->do($sql);
	    };

	    if ($@) {
		warn("DB ERROR: $@");
		return $DB_Error;
	    }
	}

    }

    my $css = $self->css || '';
    my $meta = $self->metadata('_XML') || '';
    my $assembly = $self->metadata('assembly') || '*';
    my $cs_id = 2;

    if (my $cs = $self->metadata('coordinate_system')) {
	my $sql2 = qq{ select id from coordinate_system where name = '$cs'};
	eval {
	    my $sth = $self->{_dbh}->prepare($sql2);
	    $sth->execute();
	    $cs_id = $sth->fetchrow;
	};
  
	if ($@) {
	    warn("DB ERROR: $@");
	    return $DB_Error;
	}
	if (! defined ($cs_id)) {
	    return "DB WARNING: $cs is not a recognized coordinate system";
	}
    }


    $sql = qq{ UPDATE $MASTER_TABLE SET css = '$css', meta ='$meta', coord_system = $cs_id, assembly = '$assembly', access_date = curdate() WHERE id = $jid};

    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB Error: $@");
	$self->error($DB_Error) and return -5;
    }

    $self->domain($self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER);
    return $self->_save_data();
}

sub _update_oldsource {
    my $self = shift;
    my ($dsn, $password, $action) = @_;

    delete ($self->{_error});

    $self->error($self->_db_connect()) and  return -1;
    (my $dsnid = $dsn) =~ s/^hydraeuf_(0)*//;

    my $sql = qq{select id from hydra_journal where id = '$dsnid' and passw = '$password'};
    my $jid;
    my $sth;

    warn($sql);
    eval {
        $sth = $self->{_dbh}->prepare($sql);
        $sth->execute();
        $jid = $sth->fetchrow;
    };

    if ($@) {
        warn("DB Error: $@");
        $self->error($DB_Error) and return -2;
    }
    $sth->finish;

    if (! defined($jid)) {
        $self->error("Error: no such data source or invalid password");
        return -3;
    }

    $self->dsn($dsn);
    (my $table_name = $dsn) =~ s/hydraeuf_/euf_/;

    if ($action eq 'overwrite') {

        $sql = qq{delete from $table_name};
        eval {
            $self->{_dbh}->do($sql);
        };

        if ($@) {
            warn("DB Error: $@");
            $self->error($DB_Error) and return -4;
        }
    }
    if (my $css = $self->css) {
        $sql = qq{ UPDATE hydra_journal SET css = '$css' WHERE id = $jid};
        eval {
            $self->{_dbh}->do($sql);
        };

        if ($@) {
            warn("DB Error: $@");
            $self->error($DB_Error) and return -5;
        }
    }

    $self->domain($self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER);

    $sql = qq{insert into $table_name (groupname, featureid, featuretype, featuresubtype, segmentid, start, end, strand, phase, score, alignment_start, alignment_end) values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)};
  my $icount = 0;

    eval {
	my $sth = $self->{_dbh}->prepare($sql);

	foreach (keys (%{$self->features})) {
	    my $hashref = $self->features->{$_};
	    $sth->execute($hashref->{featureid}, $hashref->{featureid}, $hashref->{featuretype}, $hashref->{featuresubtype}, $hashref->{segmentid}, $hashref->{start}, $hashref->{end}, $hashref->{strand}, $hashref->{phase}, $hashref->{score}, $hashref->{alignment_start}, $hashref->{alignment_end}  );
	    $icount ++;
	}
	$sth->finish();
    };

    if ($@) {
	warn("DB ERROR: $@");
	$self->error($DB_Error);
	return -3;
    }
    return ($icount, 0);
}

1;

