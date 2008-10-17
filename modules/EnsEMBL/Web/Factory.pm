package EnsEMBL::Web::Factory;

use strict;
use warnings;
no warnings "uninitialized";
use EnsEMBL::Web::CoreObjects;

use base qw(EnsEMBL::Web::Proxiable);

## Additional Factory functionality

sub new {
  my ($class,$data) = @_;
  my $self  = $class->SUPER::new( $data );
  return $self;
}

sub DataObjects {
  my $self = shift;
  push @{$self->{'data'}{'_dataObjects'}}, @_ if @_;
  return $self->{'data'}{'_dataObjects'};
}

sub fastCreateObjects {
  my $self = shift;
  $self->createObjects(@_);
}

sub clearDataObjects {
  my $self = shift;
  $self->{'data'}{'_dataObjects'} = [];
}

sub featureIds {
  my $self = shift;
  $self->{'data'}{'_feature_IDs'} = shift if @_;
  return $self->{'data'}{'_feature_IDs'};
}

sub _archive {
  my( $self, $type, $parameter ) = @_;

#   Redirect -> now uses code in idhistory
  my $db        = $self->param('db')||'core';
   my $name      = $self->param($parameter) || $self->param('peptide') || $self->param('transcript') || $self->param('gene');
   my @features  = undef;
   my $adaptor;

   my $related;
   my $archiveStableID ;
   eval {
     my $achiveStableIDAdaptor = $self->database($db)->get_ArchiveStableIdAdaptor();
     $name =~ s/(\S+)\.(\d+)/$1/;  # remove version
     $archiveStableID       = $achiveStableIDAdaptor->fetch_by_stable_id( $name );
     #$related               = $achiveStableIDAdaptor->fetch_successor_history( $archiveStableID ) if $archiveStableID;
   };
   return undef if (!$archiveStableID);
   #my @rel = map { $_->stable_id ? $_ : () } @$related;
   #my $caption = '';
   #my $output  = '';
   #my $probtype= '';
   #if( @rel ) {
      $self->problem('archived');
   #}
#     $caption = 'Archived identifier';
#     $probtype= 'archived';
#     $output  = "<p>The feature <strong>$name</strong> has been mapped to the following feature(s):</p>";
#     my %scripts = qw(Gene geneview Translation protview Transcript transview);
#     my %attribs = qw(Gene gene Translation peptide Transcript transcript);
#     $output .= '<ul>';
#     foreach my $asi ( @rel ) {
#       $output .= sprintf( '<li><a href="/%s/%s?%s=%s">%s</a></li>',
#         $self->species, $scripts{$asi->type}, $attribs{$asi->type}, $asi->stable_id, $asi->stable_id );
#     }
#     $output .= "</ul>\n";
#   } else {
#     $probtype= 'removed';
#     $caption = 'Identifier removed from database';
#     $output  = "<p>The feature <strong>$name</strong> has been removed from the current database.</p>";
#   }

#   # Give peptide sequence or link to current protview
#   my $trans_id = $archiveStableID->get_all_translation_archive_ids();
#   my %tmp = map { $_->stable_id, $_ } @$trans_id; #rm duplicates
#   my @trans = values %tmp;

#   unless ( @trans ) {
#     $self->problem( $probtype, $caption, $output );
#     return undef ;
#   }
#   if ( $archiveStableID->type eq 'Translation' ) {
#     $output .= qq(<p>This peptide's sequence was:</p>
#                  <table border="0">);
#   }  elsif (@trans >1){
#     $output .= qq(<p>The peptides related to ).lc($archiveStableID->type).
#       qq( <strong>$name</strong> are:</p> <table border="0">);
#   } else {
#     $output .= qq(<p>The peptide related to ).lc($archiveStableID->type).
#       qq( <strong>$name</strong> is:</p><table border="0">);
#   }
#   for (@trans) {
#     if( my $seq = $_->get_peptide ) { # there is seq in archive db
#       $seq =~ s/(\w{60})/$1<br \/>/g ;
#       $seq =~ s/<br \/>$//;
#       $output .= qq(<tr valign="top"><th>).$_->stable_id."&nbsp;</th><td><tt>$seq</tt></td></tr>\n";
#     } else { # it must still be in Ensembl, but check..
#       my $adaptor = $self->database($db)->get_TranslationAdaptor();
#       my $peptide = $adaptor->fetch_by_stable_id($name);
#       if ($peptide) {
#        $output .= sprintf( '<tr valign="top"><th><a href="/%s/protview?peptide=%s">%s</a>&nbsp;</th><td>is still in Ensembl</td></tr>',
#                          $ENV{'ENSEMBL_SPECIES'}, $_->stable_id, $_->stable_id );
#       }
#       else {
#        $output .= "<tr><th>unknown</th></tr>";
#        warn "***********ERROR: $name is not in Ensembl or Archive database!!";
#       }
#     }
#   }
#   $output .= "</table>";
#   $self->problem( $probtype, $caption, $output );
  return undef ;
}

sub _known_feature {
  my( $self, $type, $parameter ) = @_;
  my $db        = $self->param('db')||'core';
  my $name      = $self->param($parameter)||$self->param(lc(substr($parameter,0,1)))||$self->param('peptide') || $self->param('transcript') || $self->param('gene');
  my $sitetype = $self->species_defs->ENSEMBL_SITETYPE || 'Ensembl';
  my @features  = ();
  my $adaptor;
  my $adaptor_name = "get_$type".'Adaptor';
  eval { $adaptor = $self->database($db)->$adaptor_name;};
    die ("Datafactory: Unknown DBAdapter in get_known_feature: $@") if ($@);
  eval {
    my $f = $adaptor->fetch_by_display_label($name);
    push @features,$f if $f;
  };
  unless(@features) {
    eval {
      @features = @{$adaptor->fetch_all_by_external_name($name)};
    };
  }
  if( $@ ) {
    $self->problem('fatal', "Error retrieving $type from database", "An error occured while trying to retrieve the $type $name. ");
    return;
  } elsif( @features ) {
    $self->__data->{'objects'} = [ map { { 'db' => $db, lc($type) => $_->stable_id } } @features ];
    if( scalar(@features) == 1){
      $self->problem('mapped_id', 'Re-Mapped Identifier', 'The identifer has been mapped to a synonym' );
    } else {
      $self->problem('mapped_id', 'Multiple mapped IDs',  'This feature id maps to multiple synonyms'  );
    }
  } else {
    my $db_adaptor = $self->database(lc($db));
    my $uoa = $db_adaptor->get_UnmappedObjectAdaptor;
    eval { @features = @{$uoa->fetch_by_identifier($name)}; };
    if (!$@ && @features) {
      $self->problem('unmapped');
    }
    else {
      $self->problem('fatal', "$type '$name' not found", "The identifier '$name' is not present in the current release of the $sitetype database. ")  ;
    }
  }
  return;
}


1;
