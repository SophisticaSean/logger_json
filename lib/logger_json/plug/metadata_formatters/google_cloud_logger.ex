defmodule LoggerJSON.Plug.MetadataFormatters.GoogleCloudLogger do
  @moduledoc """
  This formatter builds a metadata which is natively supported by Google Cloud Logger:

    * `httpRequest` - see [LogEntry#HttpRequest](https://cloud.google.com/logging/docs/reference/v2/rest/v2/LogEntry#HttpRequest);
    * `client.api_version` - version of API that was requested by a client;
    * `phoenix.controller` - Phoenix controller that processed the request;
    * `phoenix.action` - Phoenix action that processed the request;`
    * `node.hostname` - node hostname;
    * `node.pid` - Erlang VM process identifier.
  """

  @doc false
  def build_metadata(conn, latency, client_version_header) do
    latency_second = native_to_seconds(latency)

    [
      httpRequest: %{
        requestMethod: conn.method,
        requestUrl: request_url(conn),
        status: conn.status,
        userAgent: LoggerJSON.Plug.get_header(conn, "user-agent"),
        remoteIp: remote_ip(conn),
        referer: LoggerJSON.Plug.get_header(conn, "referer"),
        latency: "#{latency_second}s"
      }
    ] ++ client_metadata(conn, client_version_header) ++ phoenix_metadata(conn) ++ node_metadata()
  end

  defp native_to_seconds(nil) do
    nil
  end

  defp native_to_seconds(native) do
    round(System.convert_time_unit(native, :native, :microsecond) / 10000) * 10000
  end

  defp request_url(%{request_path: "/"} = conn), do: "#{conn.scheme}://#{conn.host}/"
  defp request_url(conn), do: "#{conn.scheme}://#{Path.join(conn.host, conn.request_path)}"

  defp remote_ip(conn) do
    LoggerJSON.Plug.get_header(conn, "x-forwarded-for") || to_string(:inet_parse.ntoa(conn.remote_ip))
  end

  defp client_metadata(conn, client_version_header) do
    if api_version = LoggerJSON.Plug.get_header(conn, client_version_header) do
      [client: %{api_version: api_version}]
    else
      []
    end
  end

  defp phoenix_metadata(%{private: %{phoenix_controller: controller, phoenix_action: action}}) do
    [phoenix: %{controller: controller, action: action}]
  end

  defp phoenix_metadata(_conn) do
    []
  end

  defp node_metadata do
    {:ok, hostname} = :inet.gethostname()

    vm_pid =
      case Integer.parse(System.get_pid()) do
        {pid, _units} -> pid
        _ -> nil
      end

    [node: %{hostname: to_string(hostname), vm_pid: vm_pid}]
  end
end
