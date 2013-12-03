#
# Copyright (c) 2013 Eric Monti
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'idevice/c'
require 'idevice/plist'
require 'idevice/idevice'
require 'idevice/lockdown'

module Idevice
  class SbservicesError < IdeviceLibError
  end

  SBSError = SbservicesError

  class SbservicesClient < C::ManagedOpaquePointer
    include LibHelpers

    def self.release(ptr)
      C.sbservices_client_free(ptr) unless ptr.null?
    end

    def self.attach(opts={})
      _attach_helper("com.apple.springboardservices", opts) do |idevice, ldsvc, p_sbs|
        err = C.sbservices_client_new(idevice, ldsvc, p_sbs)
        raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS

        sbs = p_sbs.read_pointer
        raise SBSError, "sbservices_client_new returned a NULL client" if sbs.null?
        return new(sbs)
      end
    end

    def get_icon_state
      FFI::MemoryPointer.new(:pointer) do |p_state|
        err = C.sbservices_get_icon_state(self, p_state, nil)
        raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS
        return p_state.read_pointer.read_plist_t
      end
    end

    def set_icon_state(newstate)
      err = C.sbservices_set_icon_state(self, Plist_t.from_ruby(newstate))
      raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS

      return true
    end

    def get_icon_pngdata(bundleid)
      FFI::MemoryPointer.new(:pointer) do |p_pngdata|
        FFI::MemoryPointer.new(:uint64) do |p_pngsize|
          err = C.sbservices_get_icon_pngdata(self, bundleid, p_pngdata, p_pngsize)
          raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS

          pngdata = p_pngdata.read_pointer
          unless pngdata.null?
            ret=pngdata.read_bytes(p_pngsize.read_uint64)
            C.free(pngdata)
            return ret
          end
        end
      end
    end

    INTERFACE_ORIENTATIONS = [
      :UNKNOWN,              # => 0,
      :PORTRAIT,             # => 1,
      :PORTRAIT_UPSIDE_DOWN, # => 2,
      :LANDSCAPE_RIGHT,      # => 3,
      :LANDSCAPE_LEFT,       # => 4,
    ]

    def get_interface_orientation
      FFI::MemoryPointer.new(:int) do |p_orientation|
        err = C.sbservices_get_interface_orientation(self, p_orientation)
        raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS

        orientation = p_orientation.read_int
        return (INTERFACE_ORIENTATIONS[orientation] or orientation)
      end
    end

    def get_home_screen_wallpaper_pngdata
      FFI::MemoryPointer.new(:pointer) do |p_pngdata|
        FFI::MemoryPointer.new(:uint64) do |p_pngsize|
          err = C.sbservices_get_home_screen_wallpaper_pngdata(self, p_pngdata, p_pngsize)
          raise SbservicesError, "Springboard Services Error: #{err}" if err != :SUCCESS

          pngdata = p_pngdata.read_pointer
          unless pngdata.null?
            ret=pngdata.read_bytes(p_pngsize.read_uint64)
            C.free(pngdata)
            return ret
          end
        end
      end
    end

  end

  SBSClient = SbservicesClient

  module C
    ffi_lib 'imobiledevice'

    typedef enum(
      :SUCCESS      ,         0,
      :INVALID_ARG  ,        -1,
      :PLIST_ERROR  ,        -2,
      :CONN_FAILED  ,        -3,
      :UNKNOWN_ERROR,      -256,
    ), :sbservices_error_t

    #sbservices_error_t sbservices_client_new(idevice_t device, lockdownd_service_descriptor_t service, sbservices_client_t *client);
    attach_function :sbservices_client_new, [Idevice, LockdownServiceDescriptor, :pointer], :sbservices_error_t

    #sbservices_error_t sbservices_client_free(sbservices_client_t client);
    attach_function :sbservices_client_free, [SBSClient], :sbservices_error_t

    #sbservices_error_t sbservices_get_icon_state(sbservices_client_t client, plist_t *state, const char *format_version);
    attach_function :sbservices_get_icon_state, [SBSClient, :pointer, :string], :sbservices_error_t

    #sbservices_error_t sbservices_set_icon_state(sbservices_client_t client, plist_t newstate);
    attach_function :sbservices_set_icon_state, [SBSClient, Plist_t], :sbservices_error_t

    #sbservices_error_t sbservices_get_icon_pngdata(sbservices_client_t client, const char *bundleId, char **pngdata, uint64_t *pngsize);
    attach_function :sbservices_get_icon_pngdata, [SBSClient, :string, :pointer, :pointer], :sbservices_error_t

    #sbservices_error_t sbservices_get_interface_orientation(sbservices_client_t client, sbservices_interface_orientation_t* interface_orientation);
    attach_function :sbservices_get_interface_orientation, [SBSClient, :pointer], :sbservices_error_t

    #sbservices_error_t sbservices_get_home_screen_wallpaper_pngdata(sbservices_client_t client, char **pngdata, uint64_t *pngsize);
    attach_function :sbservices_get_home_screen_wallpaper_pngdata, [SBSClient, :pointer, :pointer], :sbservices_error_t

  end
end
