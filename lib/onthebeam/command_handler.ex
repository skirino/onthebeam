defmodule Onthebeam.CommandHandler do
  use GenServer

  # Public API
  def start_link do
    :gen_server.start_link({ :local, :onthebeam_command_handler }, __MODULE__, [], [])
  end

  # Inner modules
  defmodule Nodes do
    def list do
      Enum.map(all_nodes, fn(n) ->
        :rpc.call(n, Nodes, :info, [])
      end)
    end

    def info do
      { :ok, ifaddrs } = :inet.getifaddrs
      ifs = Enum.map(ifaddrs, fn({ ifname, ifopts }) -> { ifname, Dict.get(ifopts, :addr) } end)
      [
        name:    Node.self,
        net_ifs: ifs,
      ]
    end

    def select(pattern) do
      lower_pattern = String.downcase List.to_string(pattern)
      matches = Enum.filter(all_nodes, fn(n) -> node_matches?(n, lower_pattern) end)
      if length(matches) == 1 do
        List.first matches
      else
        raise "Node is not uniquely determined!"
      end
    end

    defp node_matches?(node, pattern) do
      String.contains? String.downcase(Atom.to_string(node)), pattern
    end

    defp all_nodes do
      [Node.self | Node.list(:visible)]
    end
  end

  defmodule Shell do
    def run(node_pattern, command) do
      node = Nodes.select(node_pattern)
      :rpc.call(node, :os, :cmd, [command])
    end
  end

  defmodule Clipboard do
    def sync_from(node_pattern) do
      put_content get_content_on(Nodes.select(node_pattern))
    end
    def sync_to(node_pattern) do
      put_content_on(Nodes.select(node_pattern), get_content)
    end

    defp get_content_on(node) do
      :rpc.call(node, __MODULE__, :get_content, [])
    end
    def get_content do
      List.to_string :os.cmd(get_content_cmd)
    end

    defp put_content_on(node, content) do
      :rpc.call(node, __MODULE__, :put_content, [content])
    end
    def put_content(content) do
      content_chomp = String.rstrip(content, ?\n)
      tmp_path = Path.join System.tmp_dir!, "onthebeam_clipboard.txt"
      :ok = File.write!(tmp_path, content_chomp)
      _output = :os.cmd put_content_cmd(tmp_path)
      :ok = File.rm tmp_path
    end

    defp get_content_cmd do
      cmd_dict = %{
        "xsel"        => 'xsel --output',
        "pbpaste"     => 'pbpaste',
        "getclip.exe" => 'getclip',
      }
      Dict.get(cmd_dict, find_clipboard_cli_for_env)
    end
    defp put_content_cmd(tmp_path) do
      cmd_dict = %{
        "xsel"        => 'cat "#{tmp_path}" | xsel --input --clipboard',
        "pbpaste"     => 'cat "#{tmp_path}" | pbcopy'                  ,
        "getclip.exe" => 'cat "#{tmp_path}" | putclip'                 ,
      }
      Dict.get(cmd_dict, find_clipboard_cli_for_env)
    end
    defp find_clipboard_cli_for_env do
      cmd = System.find_executable("xsel") || System.find_executable("pbpaste") || System.find_executable("getclip.exe")
      if cmd == nil do
        raise "No command line tool for clipboard found!"
      end
      Path.basename cmd
    end
  end

  defmodule Files do
    def download(node_pattern, path) do
      node = Nodes.select(node_pattern)
      { :ok, content } = :rpc.call(node, File, :read, [path])
      save_file_to_tmp(path, content)
    end

    def upload(node_pattern, path) do
      node = Nodes.select(node_pattern)
      { :ok, content } = File.read(path)
      :rpc.call(node, __MODULE__, :save_file_to_tmp, [path, content])
    end

    def save_file_to_tmp(path, content) do
      dest_path = Path.join System.tmp_dir!, Path.basename(path)
      File.write!(dest_path, content)
      Clipboard.put_content dest_path
    end
  end

  # Callbacks
  def handle_call({ :nodes }, _from, state) do
    { :reply, Nodes.list, state }
  end
  def handle_call({ :shell, node, cmd }, _from, state) do
    { :reply, Shell.run(node, cmd), state }
  end
  def handle_call({ :download, node, path }, _from, state) do
    { :reply, Files.download(node, path), state }
  end
  def handle_call({ :upload, node, path }, _from, state) do
    { :reply, Files.upload(node, path), state }
  end
  def handle_call({ :pullclip, node }, _from, state) do
    { :reply, Clipboard.sync_from(node), state }
  end
  def handle_call({ :pushclip, node }, _from, state) do
    { :reply, Clipboard.sync_to(node), state }
  end
end
