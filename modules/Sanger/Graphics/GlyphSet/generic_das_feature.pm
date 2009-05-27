package Sanger::Graphics::GlyphSet::generic_das_feature;

use strict;

use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Circle;
use Sanger::Graphics::Bump;

use Bio::Das;
use Data::Dumper;

use base qw(Sanger::Graphics::GlyphSet);

our $TMP_OBJ      = [];

sub init_label {
    die "function init_label() must be implemented in subclass";
}

sub _init {
    die "function _init() must be implemented in subclass";
}

####################################################################################
## fetch DAS clone/contigs and cache...
sub fetch_assembly_segments {
    my ($self,$chr_name,$start,$end,$type,$refserver,$refdsn) = @_;

    ## fetch DAS clone/contigs...
    my $segment     = ["$chr_name:$start,$end"];    
    my $assm_segs;
    my $components;
    
    if ($self->{'container'}->{'contig_cache'}){
        #print STDERR "Using assembly segment cache!\n" if ($self->_debug());
        $assm_segs  = $self->{'container'}->{'assembly_segs_cache'};
    } else {
        $components = $self->get_das_features($type,$segment,$refserver,$refdsn);
        $self->{'container'}->{'contig_cache'} =  $components;    
                
        foreach my $c (sort { $a->start() <=> $b->start() } @{$components}){
            ### eg: components/AF134726.1.1.180283
            my $component = $c;
            #print STDERR "NAME BEFORE: ", $c, "\n";
	    # $component =~ s/components\/(\S+)\.(\d+)\.(\d+)\.(\d+)/$1/;
            $component =~ s/components\///;
            $component =~ s/(\S+)\.(\d+)\.(\d+)\.(\d+)/$1/;
            $component =~ s/(\S+)\.(\d+)/$1\.$2/;
            #print STDERR "NAME AFTER: ", $component, "\n";
            $self->{'container'}->{'contig_assembly'}->{$component}->{'assembly_start'} = $c->start();
            $self->{'container'}->{'contig_assembly'}->{$component}->{'assembly_end'}   = $c->end();
            $self->{'container'}->{'contig_assembly'}->{$component}->{'assembly_ori'}   = $c->orientation();
            $self->{'container'}->{'contig_assembly'}->{$component}->{'assembly_ctg'}   = $c;
            $self->{'container'}->{'contig_assembly'}->{$component}->{'assembly_cln'}   = $component;

            my ($seg_start,$seg_end);
            my $component_length = ($c->end() - $c->start() + 1);

            if ($c->orientation() eq "+"){
                if(($start <= $c->start()) && ($end >= $c->end())){ # component is complete contained in request
                    $seg_start = 1;
                    $seg_end = $component_length;
                } elsif ($end >= $c->end()){
                    $seg_start = $start - $c->start();
                    $seg_end = $component_length;
                } else {
                    $seg_end = $component_length - ($c->end() - $end + 1);
                    if ($c->start() >= $start){
                        $seg_start = 1;
                    } else {
                        $seg_start   = $start - $c->start();
                    }
                }
            } elsif ($c->orientation() eq "-"){
                if(($start <= $c->start()) && ($end >= $c->end())){ # component is complete contained in request
                    $seg_start = 1;
                    $seg_end = $component_length;
                } elsif ($end >= $c->end()){
                    $seg_start = 1;
                    $seg_end   = $component_length - ($start - $c->start() + 1);
                } else {
                    $seg_start = $c->end() - $end;
                    if($c->start() >= $start){
                        $seg_end = $component_length;
                    } else {
                        $seg_end = $component_length - ($start -  $c->start());
                    }
                }
            } else {
                #die "Cannot get assembly component orientation. Bailing out!\n";
            }

            unless ($seg_start && $seg_end){
                warn "Bad segment start or end! [ignoring component: $component]\n";
                next;
            }

            #print STDERR "SEGMENT: $component:$seg_start,$seg_end\n";
            ## save the request segment... 
            push(@{$assm_segs},"$component:$seg_start,$seg_end");
        }    
    }
    
    $assm_segs ||= [];
    $self->{'container'}->{'assembly_segs_cache'} =  $assm_segs;    

    return($assm_segs);
}

####################################################################################
## fetch features by type and cache ones on opposite strand...
sub fetch_grouped_das_clone_features {

    my ($self,$segs_ref,$type,$annserver,$anndsn) = @_;
    
    my $das_cache_type = $type;         # in case we do an unrestricted feature fetch
    $das_cache_type ||= "all";
    $das_cache_type = "$anndsn:$das_cache_type" . ":" . join(":",@{$segs_ref}); # make cache name unique

    my $c_features;
    my $tmp = {};
    my $group;
    my $local_group = {};
    
    if ($self->{'container'}->{$das_cache_type}->{'group_cache'}){
        #print STDERR "** Using clone grouped-feature cache for type: $type **\n";
        return($self->{'container'}->{$das_cache_type}->{'group_cache'});
    } else {
        $c_features = $self->get_das_features($type, $segs_ref, $annserver, $anndsn);
        
        foreach my $f (@{$c_features}){
            ## re-map features to assembly coordinates...
            my ($global_start,$global_end,$global_ori,$hidden) = $self->remap_feature($f);
            
            $f->start($global_start);
            $f->end($global_end);
            $f->orientation($global_ori);

            my $fid = $f->id();
            $fid =~ s/\/\d+//;
            $f->id($fid);
            $group = $f->group();
            
            if($global_ori != $self->strand()){
                unless ($local_group->{$group}){
                    $local_group->{$group} = [];
                }
                push(@{$local_group->{$group}},$f);
             } else {
                push (@{$tmp->{$group}},$f);
            }
        }
        $self->{'container'}->{$das_cache_type}->{'group_cache'} = $local_group;
        return($tmp);
    }
}

####################################################################################
## fetch features by type and cache ones on opposite strand...
sub fetch_das_clone_features {

    my ($self,$segs_ref,$type,$annserver,$anndsn) = @_;
    
    my $das_cache_type = $type;         # in case we do an unrestricted feature fetch
    $das_cache_type ||= "all";
    $das_cache_type = "$anndsn:$das_cache_type" . ":" . join(":",@{$segs_ref}); # make cache name unique

    my $c_features;
    my $tmp = [];
    my $local_cache = [];
    
    if ($self->{'container'}->{$das_cache_type}->{'clone_cache'}){
        #print STDERR "** Using clone cache for type: $type **\n";
        return($self->{'container'}->{$das_cache_type}->{'clone_cache'});
    } else {
        $c_features = $self->get_das_features($type, $segs_ref, $annserver, $anndsn);
        
        foreach my $f (@{$c_features}){
            ## re-map features to assembly coordinates...
            my ($global_start,$global_end,$global_ori,$hidden) = $self->remap_feature($f);
            
            $f->start($global_start);
            $f->end($global_end);
            $f->orientation($global_ori);

            my $fid = $f->id();
            $fid =~ s/\/\d+//;
            #warn($fid);
            $f->id($fid);
            
            if($global_ori != $self->strand()){
                push(@{$local_cache},$f);
             } else {
                push (@{$tmp},$f);
            }
        }
        
        $self->{'container'}->{$das_cache_type}->{'clone_cache'} = $local_cache;

	if ( exists ($ENV{'MERGE_DAS_STRANDS'}) && ( $ENV{'MERGE_DAS_STRANDS'} == 1) ) {
	  $tmp = \(@{$tmp},@{$local_cache});
        }
      return($tmp);
    }
}

####################################################################################
## fetch features by type and cache ones on opposite strand...
sub fetch_das_assembly_features {

    my ($self,$segs_ref,$type,$annserver,$anndsn) = @_;
    
    
    my $container   = $self->{'container'};
    my $start       = $container->start();
    my $end         = $container->end();
    my $strand      = $self->strand();


    my $das_cache_type = $type;         # in case we do an unrestricted feature fetch
    $das_cache_type ||= "all";
    $das_cache_type = "$anndsn:$das_cache_type" . ":" . join(":",@{$segs_ref}); # make cache name unique
    
    my $c_features;
    my $tmp = [];
    my $fori;
        
    if (exists $self->{'container'}->{$das_cache_type}->{'feature_cache'}){
        #print STDERR "** Using assembly feature cache for type: $das_type **\n";
        return($self->{'container'}->{$das_cache_type}->{'feature_cache'});
    } else {
        #print STDERR "DAS assembly fetch for $das_type on strand $strand...\n";
        $self->{'container'}->{$das_cache_type}->{'feature_cache'} = [];
        $c_features = $self->get_das_features($type, $segs_ref, $annserver, $anndsn);
        foreach my $f (@{$c_features}){
            #print STDERR "DAS features: ", $f->id(),",", $f->start(),",",  $f->end(),"\n" if ($f->id() eq "null");
            
            if ($f->start() < $start){ # trim to assembly coordinates
                $f->start($start);
            }
            if ($f->end() > $end){
                $f->end($end);
            }

            $fori   = 1;
            $fori   = -1 if ($f->orientation() eq "-");

            my $fid = $f->id();
            $fid    =~ s/\/\d+//;
            $f->id($fid);
            

            if($fori != $strand){
                #print STDERR "Caching $fid (not on strand $strand)\n";
                push(@{$self->{'container'}->{$das_cache_type}->{'feature_cache'}},$f);
             } else {
                #print STDERR "Stacking $fid\n";
                push (@{$tmp},$f);
            }
        }
        return($tmp);
    }
}

###########################################################################################
sub remap_feature {
    my ($self, $f) = @_;

    my $seg_id      = $f->segment->ref();
    my $cstart      = $self->{'container'}->{'contig_assembly'}->{$seg_id}->{'assembly_start'};
    my $cend        = $self->{'container'}->{'contig_assembly'}->{$seg_id}->{'assembly_end'};

    my $cori        = 1;
    $cori           = -1 if($self->{'container'}->{'contig_assembly'}->{$seg_id}->{'assembly_ori'} eq "-");
    my $fori        = 1;
    $fori           = -1 if ($f->orientation() eq "-");

    my ($global_start, $global_end,$global_ori);
    
    if ($cori == 1){ 
        $global_start       = $cstart + $f->start();
        $global_end         = $cstart + $f->end();
    } else {
        $global_start       = $cend - $f->end();
        $global_end         = $cend - $f->start();
    }
    
    $global_ori =  $fori * $cori;
    
    if ($global_start < $self->{'container'}->start()){
        $global_start = $self->{'container'}->start();
    }
    if ($global_end > $self->{'container'}->end()){
        $global_end = $self->{'container'}->end();
    }

    return($global_start,$global_end,$global_ori,0);
}

###########################################################################################
sub get_das_features {
    my ($self, $type, $segment, $server, $dsn) = @_;
            
    my $type_label;
    if (ref($type) eq "ARRAY"){
        ## type is an array ref
        $type_label = join(", ",@{$type});
    } else {
        ## type is a simple string
        $type_label = $type;
        $type = [$type];
    }
    $type_label ||= "all features";
    
    #$self->_debug(1);

    warn "Fetching $type_label for segment(s): " , join(",",@{$segment}) , " from \"$dsn\"...\n" if $self->_debug();
    local $^W = 0;     

    my $dbh = Bio::Das->new(60);
    my $response = $dbh->features(
            -dsn                =>  "$server/$dsn",
            -segment            =>  $segment,
            -callback           =>  \&feature_callback,
            -segment_callback   =>  \&segment_callback,
            -type               =>  $type,
    );

    if ($response->is_success()){
        print STDERR "SUCCESS\n" if($self->_debug());
    } else {
        print STDERR "DAS feature fetch failed from $dsn!\n";
        print STDERR Dumper($response);
        return([]);
    }
    
    my @temp_das_features_array = @{$TMP_OBJ};
    $TMP_OBJ = [];  # empty the callback array for re-use...
    
    my $style;
    if($self->{'container'}->{'stylesheets'}->{$dsn}){
        #print STDERR "** Using cached stylesheet for $dsn **\n" if ($self->_debug());
        $style = $self->{'container'}->{'stylesheets'}->{$dsn};
    } else {
        my $style = $dbh->stylesheet(
            -dsn    =>  "$server/$dsn",
            );
        $self->{'container'}->{'stylesheets'}->{$dsn} = $style;       
    }
     
    return(\@temp_das_features_array);
}

###########################################################################################
sub get_das_feature_by_id {
    my ($self, $feature_id, $server, $dsn) = @_;
            
    #$self->_debug(1);

    local $^W = 0;     

    my $dbh = Bio::Das->new(60);
    my $response = $dbh->features(
            -dsn                =>  "$server/$dsn",
            -segment            =>  [],
            -feature_id         =>  $feature_id,
            -callback           =>  \&feature_callback,
            -segment_callback   =>  \&segment_callback,
    );

    if ($response->is_success()){
        print STDERR "SUCCESS\n" if($self->_debug());
    } else {
        print STDERR "DAS feature fetch failed from $dsn!\n";
        print STDERR Dumper($response);
        return([]);
    }
    
    my @temp_das_features_array = @{$TMP_OBJ};
    $TMP_OBJ = [];  # empty the callback array for re-use...
    
    my $style;
    if($self->{'container'}->{'stylesheets'}->{$dsn}){
        $style = $self->{'container'}->{'stylesheets'}->{$dsn};
    } else {
        my $style = $dbh->stylesheet( -dsn    =>  "$server/$dsn" );
        $self->{'container'}->{'stylesheets'}->{$dsn} = $style;       
    }
     
    return(\@temp_das_features_array);
}

###########################################################################################
sub stylesheet_callback {
    my ($category,$type,$zoom,$glyph,$attributes) = @_;
    
    # example glyph structure:

    #<DASSTYLE>
    #  <STYLESHEET version="0.01">
    #    <CATEGORY id="component">
    #      <TYPE id="static_golden_path">
    #        <GLYPH>
    #          <ARROW>
    #            <HEIGHT>10</HEIGHT>
    #            <COLOR>yellow</COLOR>
    #            <PARALLEL>yes</PARALLEL>
    #          </ARROW>
    #        </GLYPH>
    #      </TYPE>
    #    </CATEGORY>
    #  </STYLESHEET>
    #</DASSTYLE>

    #Category: default
    #Type: translation
    #Zoom: 
    #Glyph: box
    #    name: color   value: red
    #    name: linewidth   value: 1
    #    name: height   value: 15
    #    name: broken   value: true
    #    name: outlinecolor   value: black

    #print STDERR qq(
    #Category: $category
    #Type: $type
    #Zoom: $zoom
    #Glyph: $glyph
    #);
    #foreach my $key (keys %{$attributes}){
    #    print STDERR qq(        name: $key   value: ), $attributes->{$key} , "\n";
    #}    

    #push(@{$TMP_OBJ}, $f);   # save the XML features in a (cough) package global array
}

###########################################################################################
sub feature_callback {
    my $f = shift; 
    #print STDERR Dumper($f);         
    #print STDERR "Got a feature obj: ", ref($f), ":", $f->target_id(),"\n";         
    push(@{$TMP_OBJ}, $f);   # save the XML features in a (cough) package global array
}

###########################################################################################
sub segment_callback {
    my $s = shift; 
    #print STDERR Dumper($f);         
    #print STDERR "Got a segment obj: ", ref($s), "\n";         
}

###########################################################################################
sub bump {
    my ($self, $start, $end, $length, $dep ) = @_;
    my $bump_start = int($start * $self->{'pix_per_bp'} );
       $bump_start --;
       $bump_start = 0 if ($bump_start < 0);
    
    $end = $start + $length if $end < $start + $length;
    my $bump_end = int( $end * $self->{'pix_per_bp'} );
       $bump_end = $self->{'bitmap_length'} if ($bump_end > $self->{'bitmap_length'});

    my $row = &Sanger::Graphics::Bump::bump_row(
            $bump_start,    
            $bump_end,   
            $self->{'bitmap_length'}, 
            $self->{'bitmap'}
    );

    return $row > $dep ? -1 : $row;
}

###########################################################################################
sub _debug{
    my ($self,$value) = @_;
    if( defined $value) {
		$self->{'_debug'} = $value;
    }
    return $self->{'_debug'};
    
}

###########################################################################################
sub link {
    return "";
}

###########################################################################################
sub package {
    my ($self) = @_;
    return (__PACKAGE__);
}

1;
