defmodule Bno055 do
  @moduledoc """
  Low-level driver used to interact with the Bosch Sensortec
  BNO055 absolute orientation sensor.
  """
  alias Circuits.I2C

  @type address() :: 0..127
  @type operating_mode ::
          :acc_only
          | :magonly
          | :gyronly
          | :accmag
          | :accgyro
          | :maggyro
          | :amg
          | :imuplus
          | :compass
          | :m4g
          | :ndof_fmc_off
          | :ndof

  @type power_mode :: :low | :normal | :suspend

  @chip_id 0xA0

  # Operation Modes
  @config_mode 0x00
  @acc_only_mode 0x01
  @magonly_mode 0x02
  @gyronly_mode 0x03
  @accmag_mode 0x04
  @accgyro_mode 0x05
  @maggyro_mode 0x06
  @amg_mode 0x07
  @imuplus_mode 0x08
  @compass_mode 0x09
  @m4g_mode 0x0A
  @ndof_fmc_off_mode 0x0B
  @ndof_mode 0x0C

  # Power Modes
  @pwr_low 0x01
  @pwr_suspend 0x02

  # Common Registers
  @mode_register 0x3D
  @page_register 0x07
  @calibration_register 0x35
  @trigger_register 0x3F
  @pwr_register 0x3E
  @id_register 0x00

  @doc """
  Returns a boolean representing the calibration of the device.
  """
  @spec calibrated?(reference(), address()) :: boolean
  def calibrated?(ref, addr) do
    with {:ok, calibration} <- get_calibration(ref, addr) do
      Enum.all?(calibration, fn {_k, v} -> v == 3 end)
    end
  end

  @doc """
  Connects to the local I2C bus and returns a reference tuple.
  """
  @spec connect(String.t()) :: {:ok, reference()} | {:error, any()}
  def connect(bus \\ "i2c-1") do
    I2C.open(bus)
  end

  @doc """
  Checks the CHIP_ID before powering the device on; default configuration sets
  the device to `:ndof` mode.
  """
  @spec init(reference(), address(), operating_mode()) :: :ok | {:error, any()}
  def init(ref, addr, mode \\ :ndof) do
    with {:ok, <<@chip_id>>} <- I2C.write_read(ref, addr, <<@id_register>>, 1),
         {:ok, _register} <- {set_power_mode(ref, addr, :normal), :power},
         {:ok, _register} <- {I2C.write(ref, addr, <<@page_register>>), :page},
         {:ok, _register} <- {I2C.write(ref, addr, <<@trigger_register>>), :trigger} do
      Process.sleep(10)
      set_mode(ref, addr, mode)
    else
      {:ok, id} ->
        {:error, "Invalid chip ID: #{id}"}

      {{:error, reason}, register} ->
        {:error, "Unable to write to `#{register}` register: #{inspect(reason)}"}

      error ->
        error
    end
  end

  @doc """
  Returns acceleration in meters per second (m/s).
  """
  @spec get_acceleration(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_acceleration(ref, addr) do
    with {:ok,
          <<x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x08>>, 6) do
      {:ok, %{x: x / 100, y: y / 100, z: z / 100}}
    end
  end

  @doc """
  Returns angular velocity in degrees per second (°/s).
  """
  @spec get_angular_velocity(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_angular_velocity(ref, addr) do
    with {:ok,
          <<x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x14>>, 6) do
      {:ok, %{x: x / 16, y: y / 16, z: z / 16}}
    end
  end

  @doc """
  Returns the calibration readings across the device on a scale of 0-3.
  """
  @spec get_calibration(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_calibration(ref, addr) do
    with {:ok, <<system::size(2), gyro::size(2), acc::size(2), mag::size(2)>>} <-
           I2C.write_read(ref, addr, <<@calibration_register>>, 1) do
      {:ok, %{system: system, gyro: gyro, acc: acc, mag: mag}}
    end
  end

  @doc """
  Returns orientation in euler angles. Requires fusion mode to be enabled.
  See datasheet 3.6.5
  """
  @spec get_euler(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_euler(ref, addr) do
    with {:ok,
          <<h::16-little-integer-signed, r::16-little-integer-signed,
            p::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x1A>>, 6) do
      {:ok, %{heading: h / 16, roll: r / 16, pitch: p / 16}}
    end
  end

  @doc """
  Returns gravity without acceleration in meters per second (m/s).
  """
  @spec get_gravity(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_gravity(ref, addr) do
    with {:ok,
          <<x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x2E>>, 6) do
      {:ok, %{x: x / 100, y: y / 100, z: z / 100}}
    end
  end

  @doc """
  Returns linear acceleration in meters per second (m/s).
  """
  @spec get_linear_acceleration(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_linear_acceleration(ref, addr) do
    with {:ok,
          <<x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x28>>, 6) do
      {:ok, %{x: x / 100, y: y / 100, z: z / 100}}
    end
  end

  @doc """
  Returns magnetic readings in microteslas (μT).
  """
  @spec get_magnetic(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_magnetic(ref, addr) do
    with {:ok,
          <<x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <- I2C.write_read(ref, addr, <<0x0E>>, 6) do
      {:ok, %{x: x / 16, y: y / 16, z: z / 16}}
    end
  end

  @doc """
  Returns orientation in quaternions. Requires fusion mode to be enabled.
  See datasheet 3.6.5
  """
  @spec get_quaternion(reference(), address()) :: {:ok, map()} | {:error, any()}
  def get_quaternion(ref, addr) do
    with {:ok,
          <<w::16-little-integer-signed, x::16-little-integer-signed, y::16-little-integer-signed,
            z::16-little-integer-signed>>} <-
           I2C.write_read(ref, addr, <<0x20>>, 8) do
      {:ok, %{w: w / 16384, x: x / 16384, y: y / 16384, z: z / 16384}}
    end
  end

  @doc """
  Returns temperature in degrees celsius (°c).
  """
  @spec get_temperature(reference(), address()) :: {:ok, integer} | {:error, any()}
  def get_temperature(ref, addr) do
    I2C.write_read(ref, addr, <<0x34>>, 1)
  end

  @doc """
  Puts the device info configuration mode. Requires 10ms sleep.
  See datasheet table 3-6.
  """
  @spec set_mode(reference(), address(), operating_mode()) :: :ok | {:error, any()}
  def set_mode(ref, addr, :config) do
    with :ok <- I2C.write(ref, addr, <<@mode_register, @config_mode>>) do
      Process.sleep(19)
    end
  end

  @doc """
  Sets the operation mode of the device.
  """
  def set_mode(ref, addr, mode) when is_atom(mode) do
    case mode do
      :acc_only -> I2C.write(ref, addr, <<@mode_register, @acc_only_mode>>)
      :magonly -> I2C.write(ref, addr, <<@mode_register, @magonly_mode>>)
      :gyronly -> I2C.write(ref, addr, <<@mode_register, @gyronly_mode>>)
      :accmag -> I2C.write(ref, addr, <<@mode_register, @accmag_mode>>)
      :accgyro -> I2C.write(ref, addr, <<@mode_register, @accgyro_mode>>)
      :maggyro -> I2C.write(ref, addr, <<@mode_register, @maggyro_mode>>)
      :amg -> I2C.write(ref, addr, <<@mode_register, @amg_mode>>)
      :imuplus -> I2C.write(ref, addr, <<@mode_register, @imuplus_mode>>)
      :compass -> I2C.write(ref, addr, <<@mode_register, @compass_mode>>)
      :m4g -> I2C.write(ref, addr, <<@mode_register, @m4g_mode>>)
      :ndof_fmc_off -> I2C.write(ref, addr, <<@mode_register, @ndof_fmc_off_mode>>)
      :ndof -> I2C.write(ref, addr, <<@mode_register, @ndof_mode>>)
    end
  end

  @doc """
  Sets the power mode of the device.
  """
  @spec set_power_mode(reference(), address(), power_mode()) :: :ok | {:error, any()}
  def set_power_mode(ref, addr, mode) when is_atom(mode) do
    case mode do
      :low -> I2C.write(ref, addr, <<@pwr_register, @pwr_low>>)
      :normal -> I2C.write(ref, addr, <<@pwr_register>>)
      :suspend -> I2C.write(ref, addr, <<@pwr_register, @pwr_suspend>>)
    end
  end
end
