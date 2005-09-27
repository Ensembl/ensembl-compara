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


# in case of DB problems we don't want users to see all the debug info. 
my $DB_Error = "DAS Database is temporary unavailable. Please try again later. If the problem persists please contact helpdesk.";

# all DAS tables are named as FORMAT_DDDDDDDD, e.g euf_00000001 

my $EUF_DPREFIX = 'hydraeuf_'; # This is the header of the corresponding section in  proserver.ini file of the ProServer set up
my $EUF_TPREFIX = 'euf_'; # This is the basename field in the section

# e.g in case of EUF 

#[hydraeuf]
# state         = on
# adaptor       = upload_euf
# hydra         = dbi
# transport     = dbi
# basename      = euf
# dbname        = ens_upload
# host          = das1.internal.sanger.ac.uk
# port          = 3308
# username      = ensrw
# password      =

# Sets / returns  DAS source DSN 
sub dsn {
    my $self = shift;
    if (defined(my $value = shift)) {
	$self->{_dsn} = $value;
    }
    return $self->{_dsn};
}

# Sets / returns  the type of the uploaded file. So far only EUF (Ensembl Upload Format) is supported
sub file_type {
    my $self = shift;
    if (defined( my $value = shift)) {
	$self->{_file_type} = $value;
    }
    return $self->{_file_type};
}

# Sets / returns  DAS source domain
sub domain {
    my $self = shift;
    if (defined(my $value = shift)) {
	$self->{_domain} = $value;
    }
    return $self->{_domain};
}

# Parser for the uploaded data. So far only EUF (Ensembl Upload Format) is supported.

sub parse {
  my $self = shift;

  delete($self->{PARSED_DATA});
  my @lines = split(/\r|\n/, $self->data);
  my @keys = ('groupname', 'featureid', 'featuretype', 'featuresubtype', 'seqmentid', 'start', 'end', 'strand', 'phase', 'score', 'alignment_start', 'alignment_end');
  my $icount = 0;
  my $lcount = 0;
  my $BR = '###';
  my $EUF = qq{(.+)$BR(.)+$BR(.)+$BR(.)+$BR(.+)$BR(\\d+)$BR(\\d+)$BR(.)$BR(\.|0|1|2|3)$BR(.+)};
  my $EUFREF = qq{(.+)$BR(.)+$BR(.)+};

  my $lnum = scalar(@lines);

  my $fa = 1; # By default we have annotations at the beginning of the file

  while ($lcount < $lnum) {
      my $line = shift @lines;
      $lcount ++;
      if ($line =~ /\[annotation(s?)\]/) {
	  $fa = 1;
	  next;
      } elsif ($line =~ /\[.+\]/) { # Start of some other section [ references or assembly ]
	  $fa = 0;
      }

# we ignore references and assembly ( at least for the time being ). according to js5 they were required by LDAS server. Proserver works fine without them.
      next if (! $fa);

#      print "1: $line<br>";
      next if ($line =~ /^\#|^$|^\s+$/);
#      print "2: $line<br>";
      $icount ++;

# feature type and feature subtype can consist of multiple words - so we preserve single spaces, then split the line by tabs or multiple spaces then bring back the single spaces ..
# we have to do that because sometimes people cut-and-paste the date from the web pages and tabs get subsituted with multiple spaces in the process .. 

      $line =~ s/\t/$BR/g;
      $line =~ s/(\w)(\s)(\w)/$1_$3/g;
      $line =~ s/\s+/$BR/g;

#      print "3b: $line<br>";
      $line =~ s/_/ /g;
#      print "3c: $line<br>";
      if ($line !~ /$EUF/) {
	  return $self->error("ERROR: Invalid format. Line $lcount");
      }
      
      my @data = split(/$BR/, $line);
#      print("DATA: @data <hr>");

      %{$self->{PARSED_DATA}->{$icount}} = map { $_ => shift(@data) } @keys;
  }


# now read the references
#  my @refkeys = ('clone', 'clonetype', 'size');

#  foreach my $line (@lines) {
#      print "1: $line<br>";
#      $lcount ++;
#      next if ($line =~ /\[references\]/);
#      next if ($line =~ /^\#|^$|^\s+$/);
#      $icount ++;
#      $line =~ s/[\t\s]+/$BR/g;
#      print "2: $line<br>";
#      if ($line !~ /$EUFREF/) {
#	  return $self->error("ERROR: Invalid format. Line $lcount");
#      }
#      my @data = split(/$BR/, $line);
#
#      %{$self->{REFERENCES}->{$data[0]}} = map { $_ => shift(@data) } @refkeys;
#  }

  $self->file_type('EUF');
  return;
}
  

sub create_dsn {
    my $self = shift;
    my ($email, $password) = @_;
    
    delete ($self->{_error});
    
    $self->error($self->_db_connect()) and  return -1;
    $self->error($self->_create_table($email, $password)) and return -2;
    my $icount = $self->_save_data();
    $self->domain($self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER);
    return $icount;
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

# There is a master table hydra_journal 
# +-------------+-------------+------+-----+---------+----------------+
# | Field       | Type        | Null | Key | Default | Extra          |
# +-------------+-------------+------+-----+---------+----------------+
# | id          | int(11)     |      | PRI | NULL    | auto_increment |
# | ftype       | varchar(4)  |      |     | EUF     |                |
# | create_date | date        | YES  |     | NULL    |                |
# | access_date | date        | YES  | MUL | NULL    |                |
# | email       | varchar(64) | YES  | MUL | NULL    |                |
# | passw       | varchar(32) | YES  |     | NULL    |                |
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
    my $ftype = $self->file_type || 'NONE';

    my $sql = qq{insert into hydra_journal (create_date, email, passw, ftype) values (curdate(), '$email', '$password', '$ftype')};
    
    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }
    
    $sql = qq{SELECT id FROM hydra_journal WHERE email = '$email' AND access_date IS NULL};
    eval {
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$dsnid = $sth->fetchrow;
    };
  
    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }



    if ($ftype eq 'EUF') {
	my $table_name = sprintf("$EUF_TPREFIX%08d", $dsnid);  
	$self->dsn(sprintf("$EUF_DPREFIX%08d", $dsnid));  
	$sql = qq{
CREATE TABLE $table_name (
  id int not null auto_increment,
  groupname varchar(64),
  featureid varchar(64),
  featuretype varchar(32),
  featuresubtype varchar(32),
  segmentid varchar(64),
  start int,
  end int,
  strand char,
  phase char,
  score float,
  alignment_start varchar(32),
  alignment_end varchar(32),
  primary key(id), index(segmentid), index (featuretype) ) TYPE=MyISAM
};
    } else {
	return "Error: Unknow file format"; 
    }

    eval {
	$self->{_dbh}->do($sql);
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $DB_Error;
    }
   
    $sql = qq{ update hydra_journal set access_date = curdate() where id = $dsnid };
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

  (my $table_name = $self->dsn()) =~ s/$EUF_DPREFIX/$EUF_TPREFIX/;

  my $sql = qq{insert into $table_name (groupname, featureid, featuretype, featuresubtype, segmentid, start, end, strand, phase, score, alignment_start, alignment_end) values(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)};
  my $icount = 0;

  eval {
    my $sth = $self->{_dbh}->prepare($sql);

    foreach (keys (%{$self->{PARSED_DATA}})) {
      my $hashref = $self->{PARSED_DATA}->{$_};
#      warn(Dumper($hashref));
#      $sth->execute($hashref->{groupname}, $hashref->{featureid}, $hashref->{featuretype}, $hashref->{featuresubtype}, $hashref->{seqmentid}, $hashref->{start}, $hashref->{end}, $hashref->{strand}, $hashref->{phase}, $hashref->{score}, $hashref->{alignment_start}, $hashref->{alignment_end}  );

      $sth->execute($hashref->{featureid}, $hashref->{featureid}, $hashref->{featuretype}, $hashref->{featuresubtype}, $hashref->{seqmentid}, $hashref->{start}, $hashref->{end}, $hashref->{strand}, $hashref->{phase}, $hashref->{score}, $hashref->{alignment_start}, $hashref->{alignment_end}  );
      $icount ++;
    }
    $sth->finish();
  };

  if ($@) {
      warn("DB ERROR: $@");
      $self->error($DB_Error);
      return -3;
  }
  return $icount;
}  

# When we remove datasource we need to remove the corresponding entry from hydra_journal and drop the corresponding table
sub remove_dsn {
    my $self = shift;
    my ($dsn, $password) = @_;
    
    delete ($self->{_error});

    $self->error($self->_db_connect()) and  return -1;
    
    (my $dsn_id = $dsn) =~ s/^$EUF_DPREFIX(0)*//;
    my $jid;
    
    my $sql = qq{select id from hydra_journal where id = '$dsn_id' and passw = '$password'};
    eval {
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$jid = $sth->fetchrow;
    };

    if ($@) {
	warn("DB ERROR: $@");
	return $self->error($DB_Error);
    }
#  warn("$sql : $jid");

    if (! defined($jid)) {
	return $self->error("Error: no such data source or invalid password");
    }

    $sql = qq{delete from hydra_journal where id = $dsn_id and passw = '$password'};
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
    
    $self->error($self->_db_connect()) and  return -1;
    (my $dsnid = $dsn) =~ s/^$EUF_DPREFIX(0)*//;
    
    my $sql = qq{select id from hydra_journal where id = '$dsnid' and passw = '$password'};
    my $jid;

    eval {
	my $sth = $self->{_dbh}->prepare($sql);
	$sth->execute();
	$jid = $sth->fetchrow;
    };

    if ($@) {
	warn("DB Error: $@");
	$self->error($DB_Error) and return -2;
    }

    if (! defined($jid)) {
	$self->error("Error: no such data source or invalid password");
	return -3;
    }

    $self->dsn($dsn);
    
    if ($action eq 'overwrite') {
	$sql = qq{delete from $dsn};
	eval {
	    $self->{_dbh}->do($sql);
	};

	if ($@) {
	    warn("DB Error: $@");
	    $self->error($DB_Error) and return -4;
	}
    }

    my $icount = $self->_save_data();
    $self->domain($self->species_defs->ENSEMBL_DAS_UPLOAD_SERVER);
    return $icount;
}

1;

