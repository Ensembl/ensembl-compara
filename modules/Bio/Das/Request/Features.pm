package Bio::Das::Request::Features;
# $Id$
# this module issues and parses the types command, with arguments -dsn, -segment, -categories, -enumerate

use strict;
use Bio::Das::Type;
use Bio::Das::Feature;
use Bio::Das::Segment;
use Bio::Das::Request;
use Bio::Das::Util 'rearrange';

use vars '@ISA';
@ISA = 'Bio::Das::Request';

sub new {
  my $pack = shift;
  my ($dsn,$segments,$types,$categories,$feature_id,$group_id,$das,$fcallback,$scallback) 
    = rearrange([
		 ['dsn','dsns'],
		 ['segment','segments'],
		 ['type','types'],
		 ['category','categories'],
		 'feature_id',
		 'group_id',
		 'das',
		 ['callback','feature_callback'],
		 'segment_callback',
		],@_);
  my $self = $pack->SUPER::new(
               -dsn          => $dsn,
	       -callback     => $fcallback,
  	       -args => { 
                      segment    => $segments,
 		      category   => $categories,
		      type       => $types,
		      feature_id => $feature_id,
		      group_id   => $group_id,
		}
                );
  $self->{segment_callback} = $scallback if $scallback;
  $self->das($das) if defined $das;
  $self;
}

sub command { 'features' }

sub das {
  my $self = shift;
  my $d    = $self->{das};
  $self->{das} = shift if @_;
  $d;
}

sub segment_callback { shift->{segment_callback} }

sub t_DASGFF {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {
    $self->clear_results;
  }
  delete $self->{tmp};
}

sub t_GFF {
  # nothing to do here -- probably should check version
}

sub t_SEGMENT {
  my $self = shift;
  my $attrs = shift;
  if ($attrs) {    # segment section is starting
    $self->{tmp}{current_segment} = Bio::Das::Segment->new($attrs->{id},$attrs->{start},
							   $attrs->{stop},$attrs->{version},
							   $self->das,$self->dsn
							  );
    $self->{tmp}{current_feature} = undef;
    $self->{tmp}{features}        = [];
  }

  else {  # reached the end of the segment, so push result
    $self->finish_segment();
  }

}

sub finish_segment {
  my $self = shift;
  if ($self->segment_callback) {
    eval {$self->segment_callback->($self->{tmp}{current_segment}=>$self->{tmp}{features})};
    warn $@ if $@;
  } else {
    $self->add_object($self->{tmp}{current_segment},$self->{tmp}{features});
  }
  delete $self->{tmp}{current_segment};
}

sub cleanup {
  my $self = shift;
  # this fixes a problem in the UCSC server
  $self->finish_segment if $self->{tmp}{current_segment};
}

sub add_object {
  my $self = shift;
  push @{$self->{results}},@_;
}


# do nothing
sub t_UNKNOWNSEGMENT { }
sub t_ERRORSEGMENT { }

sub t_FEATURE {
  my $self = shift;
  my $attrs = shift;

  if ($attrs) {  # start of tag
    my $feature = $self->{tmp}{current_feature} = Bio::Das::Feature->new($self->{tmp}{current_segment},
									 $attrs->{id}
									);
    $feature->label($attrs->{label}) if exists $attrs->{label};
    $self->{tmp}{type} = undef;
  }

  else {
    # feature is ending. This would be the place to do group aggregation
    my $feature = $self->{tmp}{current_feature};
    my $cft = $feature->type;

    if (!$cft->complete) {
      # fix up broken das servers that don't set a method
      # the id and method will be set to the same value
      $cft->id($cft->method) if $cft->method;
      $cft->method($cft->id) if $cft->id;
    }

    if (my $callback = $self->callback) {
      $callback->($feature);
    } else {
      push @{$self->{tmp}{features}},$feature;
    }
  }
}

sub t_TYPE {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;

  my $cft = $self->{tmp}{type} ||= Bio::Das::Type->new();

  if ($attrs) {  # tag starts
    $cft->id($attrs->{id});
    $cft->category($attrs->{category})   if $attrs->{category};
    $cft->reference(1)      if $attrs->{reference} && $attrs->{reference} eq 'yes';
    $cft->has_subparts(1)   if $attrs->{subparts} && $attrs->{subparts} eq 'yes';
    $cft->has_superparts(1) if $attrs->{superparts} && $attrs->{superparts} eq 'yes';
  } else {

    # possibly add a label
    if (my $label = $self->char_data) {
      $cft->label($label);
    }

    my $type = $self->_cache_types($cft);
    $feature->type($type);
  }
}

sub t_METHOD {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  my $cft = $self->{tmp}{type} ||= Bio::Das::Type->new();

  if ($attrs) {  # tag starts
    $cft->method($attrs->{id});
  }

  else {  # tag ends

    # possibly add a label
    if (my $label = $self->char_data) {
      $cft->method_label($label);
    }

    if ($cft->complete) {
      my $type = $self->_cache_types($cft);
      $feature->type($type);
    }

  }
}

sub t_START {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->start($self->char_data) unless $attrs;
}

sub t_END {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->stop($self->char_data) unless $attrs;
}

sub t_SCORE {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->score($self->char_data) unless $attrs;
}

sub t_ORIENTATION {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->orientation($self->char_data) unless $attrs;
}

sub t_PHASE {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->phase($self->char_data) unless $attrs;
}

sub t_GROUP {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  if($attrs) {
    $feature->group_label( $attrs->{label} );
    $feature->group_type(  $attrs->{type}  );
    $feature->group(       $attrs->{id}    );
  }
}

sub t_LINK {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  if($attrs) {
      $feature->add_link( $attrs->{href} );
  } else {
      $feature->add_link_label( $self->char_data );
  }
}

sub t_NOTE {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  $feature->add_note($self->char_data) unless $attrs;
}

sub t_TARGET {
  my $self = shift;
  my $attrs = shift;
  my $feature = $self->{tmp}{current_feature} or return;
  if($attrs){ 
    $feature->target($attrs->{id},$attrs->{start},$attrs->{stop});
  } else {
    $feature->target_label($self->char_data());
  }
}

sub _cache_types {
  my $self = shift;
  my $type = shift;
  my $key = $type->_key;
  return $self->{cached_types}{$key} ||= $type;
}

# override for segmentation behavior
sub results {
  my $self = shift;
  my %r = $self->SUPER::results or return;

  # in array context, return the list of types
  return map { @{$_} } values %r if wantarray;

  # otherwise return ref to a hash
  return \%r;
}


1;
